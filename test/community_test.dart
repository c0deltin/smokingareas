import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/existence_policy.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';

ExistenceVote v(String user, bool exists, DateTime t, {String spot = 's'}) =>
    ExistenceVote(spotId: spot, userId: user, exists: exists, createdAt: t);

final t0 = DateTime(2026, 11, 1, 12);

void main() {
  group('ExistencePolicy (Waze-like)', () {
    const policy = ExistencePolicy();

    test('hidden after 3 users say it is gone', () {
      expect(policy.evaluate([v('a', false, t0), v('b', false, t0)], now: t0).hidden,
          isFalse);
      final s = policy.evaluate(
          [v('a', false, t0), v('b', false, t0), v('c', false, t0)],
          now: t0);
      expect(s.hidden, isTrue);
      expect(s.removals, 3);
    });

    test('confirmations keep a spot alive', () {
      final s = policy.evaluate([
        v('a', false, t0), v('b', false, t0), v('c', false, t0),
        v('d', true, t0), v('e', true, t0),
      ], now: t0);
      expect(s.hidden, isFalse, reason: '3 gone vs 2 still there');
      expect(s.disputed, isTrue);
    });

    test('only the latest vote of a user counts', () {
      final s = policy.evaluate([
        v('a', false, t0),
        v('a', false, t0.add(const Duration(minutes: 1))),
        v('a', false, t0.add(const Duration(minutes: 2))),
      ], now: t0.add(const Duration(hours: 1)));
      expect(s.removals, 1, reason: 'one user cannot remove a spot alone');
      expect(s.hidden, isFalse);

      final changed = policy.evaluate([
        v('a', false, t0),
        v('a', true, t0.add(const Duration(days: 1))),
      ], now: t0.add(const Duration(days: 2)));
      expect(changed.confirmations, 1);
      expect(changed.removals, 0);
    });

    test('old votes expire', () {
      final s = policy.evaluate([
        v('a', true, t0.subtract(const Duration(days: 400))),
        v('b', false, t0), v('c', false, t0), v('d', false, t0),
      ], now: t0);
      expect(s.confirmations, 0);
      expect(s.hidden, isTrue);
    });
  });

  group('LocalCommunityBackend', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('community'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('persists all tables and keeps one review per user and spot',
        () async {
      final db = LocalCommunityBackend(() async => tmp);
      await db.saveUser(UserProfile(id: 'u1', displayName: 'A', createdAt: t0));
      await db.addSpot(CommunitySpot(
          id: 'community:1',
          position: const LatLng(35.69, 139.70),
          name: 'Hinterhof',
          createdBy: 'u1',
          createdAt: t0,
          indoor: false));
      await db.saveReview(
          SpotReview(spotId: 'x', userId: 'u1', stars: 2, createdAt: t0));
      await db.saveReview(
          SpotReview(spotId: 'x', userId: 'u1', stars: 5, createdAt: t0));
      await db.addVote(v('u1', true, t0, spot: 'x'));

      final reopened = LocalCommunityBackend(() async => tmp);
      expect((await reopened.users()).single.displayName, 'A');
      expect((await reopened.spots()).single.indoor, isFalse);
      expect((await reopened.reviews()).single.stars, 5);
      expect(await reopened.votes(), hasLength(1));
    });

    test('remote backend is only a stub', () {
      final remote =
          RemoteCommunityBackend(baseUrl: Uri.parse('https://api.example'));
      expect(remote.spots(), throwsA(isA<UnimplementedError>()));
    });
  });

  group('CommunityService', () {
    late Directory tmp;
    late CommunityService service;
    late DateTime now;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('community');
      SharedPreferences.setMockInitialValues({});
      final backend = LocalCommunityBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      now = t0;
      service = CommunityService(
        backend: backend,
        photos: LocalPhotoStorage(() async => tmp),
        auth: auth,
        clock: () => now,
      );
      await service.init();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    SmokingArea osmArea() => SmokingArea(
          id: 'osm:node/42',
          position: const LatLng(35.6909, 139.7003),
          source: 'OpenStreetMap',
        );

    test('a first local profile is created automatically', () {
      expect(service.currentUser!.displayName, 'Me');
      expect(service.users, hasLength(1));
    });

    test('reported spot appears as map entry, with photo and own vote',
        () async {
      final photo = File('${tmp.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      final spot = await service.reportSpot(
        position: const LatLng(35.70, 139.70),
        name: 'Ecke hinter dem Kombini',
        indoor: false,
        photo: photo,
      );
      final area = service.spotsAsAreas.single;
      expect(area.id, spot.id);
      expect(area.tags['community'], 'yes');
      expect(area.isIndoor, isFalse);
      expect(service.photosFor(area), hasLength(1));
      expect(await service.photoFile(service.photosFor(area).single),
          isNotNull);
      expect(service.statusFor(area).confirmations, 1);
    });

    test('access: public flag and note are stored and shown', () async {
      await service.reportSpot(
        position: const LatLng(35.6812, 139.7671),
        name: 'Bahnsteig 5',
        publicAccess: false,
        accessNote: 'nur mit Bahnticket',
      );
      await service.reportSpot(
        position: const LatLng(35.6900, 139.7000),
        name: 'Park',
        publicAccess: true,
        accessNote: 'wird ignoriert',
      );
      final areas = {for (final a in service.spotsAsAreas) a.title: a};
      expect(areas['Bahnsteig 5']!.isPublic, isFalse);
      expect(areas['Bahnsteig 5']!.tags['access'], 'customers');
      expect(areas['Bahnsteig 5']!.accessNote, 'nur mit Bahnticket');
      expect(areas['Park']!.isPublic, isTrue);
      expect(areas['Park']!.accessNote, isNull);

      // survives a restart
      final reopened = await LocalCommunityBackend(() async => tmp).spots();
      final platform = reopened.firstWhere((s) => s.name == 'Bahnsteig 5');
      expect(platform.publicAccess, isFalse);
      expect(platform.accessNote, 'nur mit Bahnticket');
    });

    test('OSM access tags are understood', () {
      SmokingArea withAccess(String v) => SmokingArea(
          id: 'osm:node/$v', position: const LatLng(35, 139),
          source: 'OpenStreetMap', tags: {'access': v});
      expect(withAccess('yes').isPublic, isTrue);
      expect(withAccess('customers').isPublic, isFalse);
      expect(withAccess('private').isPublic, isFalse);
      expect(withAccess('unknown').isPublic, isNull);
    });

    test('ratings: one per user, average across users', () async {
      final a = osmArea();
      await service.rate(a, 2);
      await service.rate(a, 4, comment: 'sauber, überdacht');
      expect(service.ratingFor(a).count, 1);
      expect(service.ratingFor(a).mine, 4);

      await service.createUser('Zweiter');
      await service.rate(a, 2);
      final r = service.ratingFor(a);
      expect(r.count, 2);
      expect(r.average, 3);
      expect(r.mine, 2);
      expect(service.reviewsFor(a).map((e) => e.comment),
          contains('sauber, überdacht'));
    });

    test('three users reporting "gone" remove the spot from the map',
        () async {
      final a = osmArea();
      final repo = SmokingAreaRepository(
          sources: const [], cacheDirectory: () async => tmp);
      void sync() => repo.setCommunity(
          spots: [a, ...service.spotsAsAreas], isHidden: service.isHidden);
      sync();
      expect(repo.allVisible.map((e) => e.id), contains(a.id));

      for (final name in ['A', 'B', 'C']) {
        await service.createUser(name);
        await service.vote(a, exists: false);
        now = now.add(const Duration(minutes: 1));
      }
      sync();
      expect(service.statusFor(a).removals, 3);
      expect(service.isHidden(a), isTrue);
      expect(repo.allVisible.map((e) => e.id), isNot(contains(a.id)));
    });

    test('votes cast on the OSM id still count after merging', () async {
      final a = osmArea();
      for (final name in ['A', 'B', 'C']) {
        await service.createUser(name);
        await service.vote(a, exists: false);
      }
      // Later the same place is shown as official entry merged with OSM.
      final merged = SmokingArea(
        id: 'tokyo_shinjuku:1',
        position: a.position,
        source: 'Bezirk Shinjuku + OpenStreetMap',
        tags: const {'official': 'yes', 'osm:element': 'node/42'},
      );
      expect(service.isHidden(merged), isTrue);
    });

    test('switching users keeps data separate per user', () async {
      final a = osmArea();
      await service.vote(a, exists: true);
      final first = service.currentUser!.id;
      await service.createUser('Zweiter');
      expect(service.myVote(a), isNull);
      await service.switchUser(first);
      expect(service.myVote(a), isTrue);
    });
  });

  test('cities still resolve (sanity)', () {
    expect(cityById('tokyo'), isNotNull);
  });
}
