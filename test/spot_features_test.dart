import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/feature_policy.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/community/server_rows.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';
import 'package:smoking_areas/ui/spot_style.dart';

const _p = LatLng(35.6909, 139.7003);
final _t0 = DateTime(2026, 11, 14, 10);

FeatureVote _vote(String user, bool value, {Duration ago = Duration.zero}) =>
    FeatureVote(
      spotId: 'osm:node/1',
      userId: user,
      feature: SpotFeature.bin,
      value: value,
      createdAt: _t0.subtract(ago),
    );

const _smoking = SmokingArea(
  id: 'osm:node/1',
  position: _p,
  source: 'OpenStreetMap',
  tags: {'amenity': 'smoking_area', 'aliases': 'x:old'},
);

void main() {
  group('FeaturePolicy', () {
    const policy = FeaturePolicy();

    test('latest answer per user, majority decides, tie is undecided', () {
      var s = policy.evaluate([
        _vote('a', false, ago: const Duration(days: 2)),
        _vote('a', true),
        _vote('b', false),
      ], SpotFeature.bin, now: _t0);
      expect((s.yes, s.no), (1, 1));
      expect(s.value, isNull);

      s = policy.evaluate([_vote('a', true), _vote('c', true), _vote('b', false)],
          SpotFeature.bin, now: _t0);
      expect(s.value, isTrue);
      expect(FeatureStatus.none.value, isNull);
    });

    test('answers expire after a year', () {
      final s = policy.evaluate(
          [_vote('a', true, ago: const Duration(days: 400)), _vote('b', false)],
          SpotFeature.bin,
          now: _t0);
      expect((s.yes, s.no, s.value), (0, 1, false));
    });
  });

  group('model', () {
    test('bin tag and the trash can filter', () {
      final withBin = _smoking.withTags({'bin': 'yes'});
      expect(withBin.hasBin, isTrue);
      expect(_smoking.hasBin, isNull);
      expect(withBin.offers(SpotCategory.bin), isTrue);
      expect(withBin.offers(SpotCategory.smoking), isTrue);
      expect(_smoking.offers(SpotCategory.bin), isFalse);
      expect(SpotMarker.fromArea(withBin).bin, isTrue);
      expect(SpotMarker.fromArea(withBin).styleKey,
          isNot(SpotMarker.fromArea(_smoking).styleKey));
    });

    test('server rows', () {
      expect(
          ServerRows.featureVoteInsert(_vote('a', true)),
          {'spot_id': 'osm:node/1', 'feature': 'bin', 'value': true});
      final row = {
        'spot_id': 'osm:node/1',
        'user_id': 'a',
        'feature': 'bin',
        'value': false,
        'created_at': '2026-11-14T10:00:00Z',
      };
      expect(ServerRows.featureVote(row)?.value, isFalse);
      expect(ServerRows.featureVote({...row, 'feature': 'sauna'}), isNull);
      final spot = CommunitySpot(
        id: 'community:1',
        position: _p,
        name: 'Corner',
        bin: true,
        createdBy: 'u',
        createdAt: _t0,
      );
      expect(ServerRows.spotInsert(spot)['bin'], isTrue);
      expect(ServerRows.spotUpdate(spot)['bin'], isTrue);
    });
  });

  group('community', () {
    late Directory tmp;
    late LocalCommunityBackend backend;
    late CommunityService service;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('features');
      SharedPreferences.setMockInitialValues({});
      backend = LocalCommunityBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      service = CommunityService(
        backend: backend,
        photos: LocalPhotoStorage(() async => tmp),
        auth: auth,
        clock: () => _t0,
      );
      await service.init();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('answers mark a spot with a trash can and are stored', () async {
      expect(service.annotate(_smoking).hasBin, isNull);
      await service.voteFeature(_smoking, SpotFeature.bin, value: true);
      expect(service.annotate(_smoking).hasBin, isTrue);
      expect(service.myFeatureVote(_smoking, SpotFeature.bin), isTrue);

      // Stored and loaded again (local backend).
      await service.init();
      expect(service.featureStatus(_smoking, SpotFeature.bin).yes, 1);
      expect((await backend.featureVotes()).single.spotId, 'osm:node/1');
    });

    test('the community overrides the source data', () async {
      final tagged = _smoking.withTags({'bin': 'yes'});
      await service.voteFeature(tagged, SpotFeature.bin, value: false);
      expect(service.annotate(tagged).hasBin, isFalse);
    });

    test('answers under an old id count for the merged spot', () async {
      final old = SmokingArea(
          id: 'x:old', position: _p, source: 'City', tags: const {});
      await service.voteFeature(old, SpotFeature.bin, value: true);
      expect(service.annotate(_smoking).hasBin, isTrue);
    });

    test('reported smoking areas can have a trash can', () async {
      await service.reportSpot(
          position: _p, name: 'Corner', bin: true);
      await service.reportSpot(
          position: _p,
          name: 'Bin',
          category: SpotCategory.bin,
          bin: true);
      final areas = service.spotsAsAreas;
      expect(areas.firstWhere((a) => a.isSmoking).hasBin, isTrue);
      // A trash can does not "have" a trash can.
      expect(areas.firstWhere((a) => a.category == SpotCategory.bin).hasBin,
          isNull);
    });
  });

  testWidgets('details ask whether there is a trash can', (tester) async {
    late CommunityService service;
    final tmp = Directory.systemTemp.createTempSync('features_ui');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final backend = LocalCommunityBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      service = CommunityService(
          backend: backend,
          photos: LocalPhotoStorage(() async => tmp),
          auth: auth);
      await service.init();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AreaDetailsSheet(area: _smoking, community: service)),
    ));
    expect(find.text('Is there a trash can here?'), findsOneWidget);
    await tester.ensureVisible(find.text('Trash can (0)'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Trash can (0)'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 10 && find.text('Trash can (1)').evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Trash can (1)'), findsOneWidget);
    expect(find.text('Shown with a trash can on the map.'), findsOneWidget);
  });
}
