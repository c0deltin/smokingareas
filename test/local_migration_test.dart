import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/local_migration.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';

final now = DateTime(2026, 11, 11, 12);

/// Target that fails after [limit] writes, like the server's hourly limits.
class LimitedBackend extends LocalCommunityBackend {
  LimitedBackend(super.dir, {this.limit = 1 << 30});
  int limit;
  int writes = 0;

  Future<void> _count() async {
    if (writes++ >= limit) throw Exception('rate limit exceeded');
  }

  @override
  Future<void> addSpot(CommunitySpot spot) async {
    await _count();
    await super.addSpot(spot);
  }

  @override
  Future<void> saveReview(SpotReview review) async {
    await _count();
    await super.saveReview(review);
  }

  @override
  Future<void> addVote(ExistenceVote vote) async {
    await _count();
    await super.addVote(vote);
  }

  @override
  Future<void> addClosureReport(ClosureReport report) async {
    await _count();
    await super.addClosureReport(report);
  }

  @override
  Future<void> addPhoto(SpotPhoto photo) async {
    await _count();
    await super.addPhoto(photo);
  }
}

void main() {
  late Directory deviceDir;
  late Directory serverDir;
  late LocalCommunityBackend device;
  late LocalPhotoStorage devicePhotos;
  late LocalDataMigration migration;

  setUp(() async {
    deviceDir = Directory.systemTemp.createTempSync('device');
    serverDir = Directory.systemTemp.createTempSync('server');
    device = LocalCommunityBackend(() async => deviceDir);
    devicePhotos = LocalPhotoStorage(() async => deviceDir);
    migration = LocalDataMigration(
      local: device,
      localPhotos: devicePhotos,
      photosDirectory: () async =>
          Directory('${deviceDir.path}/community/photos'),
      clock: () => now,
    );

    // Two local profiles, as in earlier versions.
    await device.addSpot(CommunitySpot(
      id: 'community:spot-1',
      position: const LatLng(35.69, 139.70),
      name: 'Behind the station',
      createdBy: 'local-a',
      createdAt: now.subtract(const Duration(days: 30)),
    ));
    for (final (user, stars, days) in [('local-a', 2, 20), ('local-b', 5, 3)]) {
      await device.saveReview(SpotReview(
          spotId: 'osm:node/1', userId: user, stars: stars,
          createdAt: now.subtract(Duration(days: days))));
    }
    await device.addVote(ExistenceVote(
        spotId: 'osm:node/1', userId: 'local-a', exists: true,
        createdAt: now.subtract(const Duration(days: 9))));
    await device.addVote(ExistenceVote(
        spotId: 'osm:node/1', userId: 'local-b', exists: false,
        createdAt: now.subtract(const Duration(days: 1))));
    // An expired and an active closure report.
    await device.addClosureReport(ClosureReport(
        spotId: 'osm:node/2', userId: 'local-a', closed: true,
        createdAt: now.subtract(const Duration(days: 40))));
    await device.addClosureReport(ClosureReport(
        spotId: 'osm:node/3', userId: 'local-a', closed: true,
        createdAt: now.subtract(const Duration(days: 2))));
    final key = await devicePhotos.save(
        File('${deviceDir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]));
    await device.addPhoto(SpotPhoto(
        id: 'photo-1', spotId: 'osm:node/1', userId: 'local-a',
        storageKey: key, createdAt: now));
  });
  tearDown(() {
    deviceDir.deleteSync(recursive: true);
    serverDir.deleteSync(recursive: true);
  });

  test('plan: latest rating/vote per place, only active closures', () async {
    final p = await migration.plan();
    expect(p.spots, hasLength(1));
    expect(p.reviews.single.stars, 5);
    expect(p.votes.single.exists, isFalse);
    expect(p.closures.single.spotId, 'osm:node/3');
    expect(p.photos, hasLength(1));
    expect(p.count, 5);
  });

  test('upload: everything as the signed-in user, then the device is clean',
      () async {
    final server = LimitedBackend(() async => serverDir);
    final result = await migration.upload(
      target: server,
      targetPhotos: LocalPhotoStorage(() async => serverDir),
      userId: 'account-1',
    );
    expect(result.done, isTrue);
    expect(result.uploaded, 5);

    final spot = (await server.spots()).single;
    expect(spot.id, 'community:spot-1');
    expect(spot.createdBy, 'account-1');
    expect((await server.reviews()).single.userId, 'account-1');
    expect((await server.votes()).single.userId, 'account-1');
    final photo = (await server.photos()).single;
    expect(await LocalPhotoStorage(() async => serverDir)
        .resolve(photo.storageKey), isNotNull);

    expect(await migration.hasData, isFalse);
    expect(Directory('${deviceDir.path}/community/photos').existsSync(),
        isFalse);
  });

  test('interrupted by the hourly limit, the upload resumes later', () async {
    final server = LimitedBackend(() async => serverDir, limit: 2);
    final first = await migration.upload(
      target: server,
      targetPhotos: LocalPhotoStorage(() async => serverDir),
      userId: 'account-1',
    );
    expect(first.done, isFalse);
    expect(first.uploaded, 2);
    expect(first.remaining, 3);
    expect(await migration.hasData, isTrue);

    server.limit = 100;
    final second = await migration.upload(
      target: server,
      targetPhotos: LocalPhotoStorage(() async => serverDir),
      userId: 'account-1',
    );
    expect(second.done, isTrue);
    expect(second.uploaded, 3);
    expect(await server.spots(), hasLength(1));
    expect(await server.reviews(), hasLength(1));
  });

  test('discard removes data and photo files', () async {
    await migration.discard();
    expect(await migration.hasData, isFalse);
    expect((await migration.plan()).count, 0);
  });
}
