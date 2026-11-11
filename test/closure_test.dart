import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/closure_policy.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';

final t0 = DateTime(2026, 11, 10, 12);

ClosureReport r(String user, bool closed, DateTime at,
        {DateTime? until, String? note}) =>
    ClosureReport(
        spotId: 's',
        userId: user,
        closed: closed,
        createdAt: at,
        until: until,
        note: note);

void main() {
  group('ClosurePolicy', () {
    const policy = ClosurePolicy();

    test('one report closes a spot, with reason', () {
      final s = policy.evaluate([r('a', true, t0, note: 'Bauarbeiten')],
          now: t0.add(const Duration(hours: 1)));
      expect(s.closed, isTrue);
      expect(s.note, 'Bauarbeiten');
      expect(s.since, t0);
    });

    test('report expires after 14 days without end date', () {
      final reports = [r('a', true, t0)];
      expect(policy.evaluate(reports, now: t0.add(const Duration(days: 13))).closed,
          isTrue);
      expect(policy.evaluate(reports, now: t0.add(const Duration(days: 15))).closed,
          isFalse);
    });

    test('end date replaces the default duration (capped at 180 days)', () {
      final until = t0.add(const Duration(days: 40));
      final reports = [r('a', true, t0, until: until)];
      final s = policy.evaluate(reports, now: t0.add(const Duration(days: 30)));
      expect(s.closed, isTrue);
      expect(s.until, until);
      expect(policy.evaluate(reports, now: t0.add(const Duration(days: 41))).closed,
          isFalse);
      final far = [r('a', true, t0, until: t0.add(const Duration(days: 999)))];
      expect(policy.evaluate(far, now: t0.add(const Duration(days: 181))).closed,
          isFalse);
    });

    test('"reopened" cancels; latest per user; newest wins a tie', () {
      final later = t0.add(const Duration(hours: 2));
      expect(
          policy.evaluate([r('a', true, t0), r('b', false, later)],
              now: later).closed,
          isFalse);
      expect(
          policy.evaluate([r('a', true, t0), r('a', false, later)],
              now: later).closed,
          isFalse,
          reason: 'user changed their mind');
      expect(
          policy.evaluate(
              [r('a', true, t0), r('b', true, t0), r('c', false, later)],
              now: later).closed,
          isTrue,
          reason: '2 closed vs 1 reopened');
    });
  });

  group('CommunityService closures', () {
    late Directory tmp;
    late CommunityService service;
    late DateTime now;
    late LocalCommunityBackend backend;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('closure');
      SharedPreferences.setMockInitialValues({});
      backend = LocalCommunityBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      now = t0;
      service = CommunityService(
          backend: backend,
          photos: LocalPhotoStorage(() async => tmp),
          auth: auth,
          clock: () => now);
      await service.init();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    final area = SmokingArea(
        id: 'osm:node/1',
        position: const LatLng(35.69, 139.70),
        source: 'OpenStreetMap',
        tags: const {'amenity': 'toilets'});

    test('closure is shown on the map entry and persists', () async {
      final repo = SmokingAreaRepository(
          sources: const [], cacheDirectory: () async => tmp);
      repo.setCommunity(
          spots: [area],
          isHidden: service.isHidden,
          annotate: service.annotate);
      expect(repo.allVisible.single.isTemporarilyClosed, isFalse);

      await service.reportClosure(area,
          closed: true, note: 'defekt', until: t0.add(const Duration(days: 3)));
      repo.setCommunity(
          spots: [area],
          isHidden: service.isHidden,
          annotate: service.annotate);
      final shown = repo.allVisible.single;
      expect(shown.isTemporarilyClosed, isTrue);
      expect(shown.closedNote, 'defekt');
      expect(shown.closedUntil, t0.add(const Duration(days: 3)));
      expect(service.myClosureReport(area), isTrue);

      expect((await LocalCommunityBackend(() async => tmp).closureReports()),
          hasLength(1));

      now = t0.add(const Duration(days: 4));
      expect(service.annotate(area).isTemporarilyClosed, isFalse,
          reason: 'expired at its end date');
    });

    test('community can reopen a spot closed by official data', () async {
      final official = SmokingArea(
        id: 'okayama_toilets:9',
        position: const LatLng(34.66, 133.93),
        source: 'Stadt Okayama',
        tags: const {
          'official': 'yes',
          'amenity': 'toilets',
          'temporarily_closed': 'yes',
          'temporarily_closed:note': '工事中のため、休止中',
        },
      );
      expect(service.annotate(official).isTemporarilyClosed, isTrue);
      await service.reportClosure(official, closed: false);
      expect(service.annotate(official).isTemporarilyClosed, isFalse);
    });
  });

  testWidgets('details sheet shows the closed banner', (tester) async {
    final closed = SmokingArea(
      id: 'x:1',
      position: const LatLng(34.66, 133.93),
      source: 'Stadt Okayama',
      tags: {
        'amenity': 'toilets',
        'temporarily_closed': 'yes',
        'temporarily_closed:note': 'Bauarbeiten',
        'temporarily_closed:until': DateTime(2026, 12, 24).toIso8601String(),
      },
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AreaDetailsSheet(area: closed)),
    ));
    expect(find.text('Temporarily closed'), findsOneWidget);
    expect(find.text('Bauarbeiten'), findsOneWidget);
    expect(find.text('expected until 24.12.2026'), findsOneWidget);
  });
}
