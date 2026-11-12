import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';

void main() {
  testWidgets('details sheet shows community section and records votes',
      (tester) async {
    late CommunityService service;
    final tmp = Directory.systemTemp.createTempSync('community_ui');
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

    final area = SmokingArea(
      id: 'osm:node/1',
      position: const LatLng(35.69, 139.70),
      source: 'OpenStreetMap',
      name: 'Testplatz',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AreaDetailsSheet(area: area, community: service),
      ),
    ));

    expect(find.text('Testplatz'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('Yes (0)'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Yes (0)'));
      // Let the file write of the local backend finish.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Yes (1)'), findsOneWidget);
    expect(service.myVote(area), isTrue);
  });

  testWidgets('vote button shows a spinner while saving', (tester) async {
    late CommunityService service;
    late _SlowBackend backend;
    final tmp = Directory.systemTemp.createTempSync('community_busy');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      backend = _SlowBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      service = CommunityService(
          backend: backend,
          photos: LocalPhotoStorage(() async => tmp),
          auth: auth);
      await service.init();
    });

    final area = SmokingArea(
      id: 'osm:node/2',
      position: const LatLng(35.69, 139.70),
      source: 'OpenStreetMap',
      name: 'Slow place',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AreaDetailsSheet(area: area, community: service),
      ),
    ));

    Finder yes() => find.ancestor(
        of: find.text('Yes (0)'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Yes (0)'));
    await tester.pump();
    // Immediate feedback: spinner in the button, button disabled.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(yes()).enabled, isFalse);

    backend.release.complete();
    // The local backend writes a file: alternate real time and frames.
    for (var i = 0; i < 10 && find.text('Yes (1)').evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Yes (1)'), findsOneWidget);
  });
}

/// Holds votes until [release] completes.
class _SlowBackend extends LocalCommunityBackend {
  _SlowBackend(super.dir);
  final release = Completer<void>();

  @override
  Future<void> addVote(ExistenceVote vote) async {
    await release.future;
    await super.addVote(vote);
  }
}
