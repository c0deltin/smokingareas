import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/outbox.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/models/smoking_area.dart';

/// Local backend that can lose its connection or refuse writes.
class _FlakyBackend extends LocalCommunityBackend {
  _FlakyBackend(super.dir);
  bool offline = false;
  bool refuse = false;
  final sent = <String>[];

  Future<void> _write(String what) async {
    if (offline) throw const SocketException('Failed host lookup');
    if (refuse) throw Exception('new row violates row-level security policy');
    sent.add(what);
  }

  @override
  Future<void> addVote(ExistenceVote vote) async {
    await _write('vote ${vote.spotId}');
    await super.addVote(vote);
  }

  @override
  Future<void> addSpot(CommunitySpot spot) async {
    await _write('spot ${spot.id}');
    await super.addSpot(spot);
  }

  @override
  Future<void> addClosureReport(ClosureReport report) async {
    await _write('closure ${report.spotId}');
    await super.addClosureReport(report);
  }
}

const _area = SmokingArea(
  id: 'osm:node/1',
  position: LatLng(35.69, 139.70),
  source: 'OpenStreetMap',
  tags: {'amenity': 'smoking_area'},
);

void main() {
  late Directory tmp;
  late _FlakyBackend backend;
  late LocalAuthService auth;

  CommunityService service() => CommunityService(
        backend: backend,
        photos: LocalPhotoStorage(() async => tmp),
        auth: auth,
        outbox: Outbox(() async => tmp),
      );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('outbox');
    SharedPreferences.setMockInitialValues({});
    backend = _FlakyBackend(() async => tmp);
    auth = LocalAuthService(backend,
        prefs: await SharedPreferences.getInstance());
    await auth.init();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('offline contributions are shown, kept and sent later in order',
      () async {
    final s = service();
    await s.init();
    backend.offline = true;

    await expectLater(
        s.vote(_area, exists: true), throwsA(isA<SavedOffline>()));
    expect(s.myVote(_area), isTrue); // shown right away
    await expectLater(
        s.reportSpot(position: const LatLng(35.7, 139.7), name: 'Corner'),
        throwsA(isA<SavedOffline>()));
    expect(s.queuedCount, 3); // vote, spot, the spot's own vote
    expect(backend.sent, isEmpty);

    // App restart while still offline: the contributions stay visible.
    final again = service();
    await again.init();
    expect(again.queuedCount, 3);
    expect(again.myVote(_area), isTrue);
    expect(again.mySpots.map((s) => s.name), ['Corner']);

    // Back online: sent in the original order, nothing left.
    backend.offline = false;
    await again.init();
    expect(backend.sent.first, 'vote osm:node/1');
    expect(backend.sent[1], startsWith('spot community:'));
    expect(backend.sent[2], startsWith('vote community:'));
    expect(again.queuedCount, 0);
    expect(again.mySpots.map((s) => s.name), ['Corner']);
  });

  test('a new contribution online first sends what is waiting', () async {
    final s = service();
    await s.init();
    backend.offline = true;
    await expectLater(s.reportClosure(_area, closed: true),
        throwsA(isA<SavedOffline>()));
    backend.offline = false;
    await s.vote(_area, exists: true);
    expect(backend.sent, ['closure osm:node/1', 'vote osm:node/1']);
    expect(s.queuedCount, 0);
  });

  test('refusals are not kept: shown as error, and dropped when flushing',
      () async {
    final s = service();
    await s.init();
    backend.refuse = true;
    await expectLater(s.vote(_area, exists: false),
        throwsA(isNot(isA<SavedOffline>())));
    expect(s.queuedCount, 0);
    expect(s.myVote(_area), isNull);

    backend
      ..refuse = false
      ..offline = true;
    await expectLater(
        s.vote(_area, exists: true), throwsA(isA<SavedOffline>()));
    backend
      ..offline = false
      ..refuse = true;
    await s.flushOutbox();
    expect(s.queuedCount, 0);
  });

  test('offline errors are told apart from refusals', () {
    expect(isOfflineError(const SocketException('x')), isTrue);
    expect(isOfflineError(Exception('ClientException: Failed host lookup')),
        isTrue);
    expect(isOfflineError(Exception('rate limit exceeded for votes')), isFalse);
  });
}
