import 'dart:convert';
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
import 'package:smoking_areas/ui/moderation.dart';

const spot = SmokingArea(
  id: 'osm:node/1',
  position: LatLng(35.69, 139.70),
  source: 'OSM',
);

void main() {
  late Directory tmp;
  late CommunityService service;
  late String alice;
  late String bob;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('moderation');
    SharedPreferences.setMockInitialValues({});
    final backend = LocalCommunityBackend(() async => tmp);
    final auth = LocalAuthService(backend,
        prefs: await SharedPreferences.getInstance());
    await auth.init();
    service = CommunityService(
      backend: backend,
      photos: LocalPhotoStorage(() async => tmp),
      auth: auth,
    );
    await service.init();
    alice = service.currentUser!.id;
    // Bob rates, adds a photo and reports a place.
    await service.createUser('Bob');
    bob = service.currentUser!.id;
    await service.rate(spot, 1, comment: 'Spam spam');
    await service
        .addPhoto(spot, File('${tmp.path}/p.jpg')..writeAsBytesSync([1, 2, 3]))
        .done;
    await service.reportSpot(position: const LatLng(35.70, 139.70), name: 'Ad');
    await service.switchUser(alice);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('blocking hides the author\'s places, ratings and photos', () async {
    expect(service.reviewsFor(spot), hasLength(1));
    expect(service.photosFor(spot), hasLength(1));
    expect(service.spotsAsAreas, hasLength(1));

    await service.block(bob);
    expect(service.reviewsFor(spot), isEmpty);
    expect(service.photosFor(spot), isEmpty);
    expect(service.spotsAsAreas, isEmpty);

    // Blocks are stored per user and survive a reload.
    await service.refresh();
    expect(service.isBlocked(bob), isTrue);

    await service.unblock(bob);
    expect(service.reviewsFor(spot), hasLength(1));
  });

  test('blocks are personal', () async {
    await service.block(bob);
    await service.createUser('Carol');
    await service.refresh();
    expect(service.isBlocked(bob), isFalse);
    expect(service.reviewsFor(spot), hasLength(1));
  });

  test('users cannot block themselves', () async {
    await service.block(alice);
    expect(service.blockedUsers, isEmpty);
  });

  test('reports are stored for the moderators', () async {
    final review = service.reviewsFor(spot).single;
    await service.report(
        ReportTarget.review, reviewTargetId(review), 'Spam or advertising');
    final db = jsonDecode(
        File('${tmp.path}/community/db.json').readAsStringSync()) as Map;
    final report = (db['reports'] as List).single as Map;
    expect(report['target_type'], 'review');
    expect(report['target_id'], 'osm:node/1#$bob');
    expect(report['reason'], 'Spam or advertising');
  });

  group('content menu', () {
    late _MemoryBackend memory;
    setUp(() async {
      // Widget tests run in fake time: no file IO.
      memory = _MemoryBackend();
      service = CommunityService(
        backend: memory,
        photos: LocalPhotoStorage(() async => tmp),
        auth: _SignedIn(alice),
      );
      await service.init();
    });
    Future<void> settleIo(WidgetTester tester) => tester.pumpAndSettle();

    Future<void> pumpMenu(WidgetTester tester, String authorId) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: ContentMenu(
                community: service,
                target: ReportTarget.photo,
                targetId: 'photo-1',
                authorId: authorId,
                authorName: 'Bob',
              ),
            ),
          ),
        ));

    testWidgets('not shown on own content', (tester) async {
      await pumpMenu(tester, alice);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('report with a reason', (tester) async {
      await pumpMenu(tester, bob);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Block Bob'), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      // Send is disabled until a reason is chosen.
      final send = find.widgetWithText(FilledButton, 'Send');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.tap(find.text('Offensive or inappropriate'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Insults');
      await tester.tap(send);
      await settleIo(tester);
      expect(find.textContaining('will be reviewed'), findsOneWidget);
      expect(memory.reports.single,
          ('photo', 'photo-1', 'Offensive or inappropriate: Insults'));
    });

    testWidgets('block after confirming', (tester) async {
      await pumpMenu(tester, bob);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await settleIo(tester);
      expect(service.isBlocked(bob), isTrue);
    });
  });

  test('anonymous users cannot report or block', () async {
    final anonymous = CommunityService(
      backend: LocalCommunityBackend(() async => tmp),
      photos: LocalPhotoStorage(() async => tmp),
      auth: _Anonymous(),
    );
    expect(() => anonymous.report(ReportTarget.spot, 'x', 'Other'),
        throwsA(isA<SignInRequired>()));
    await expectLater(anonymous.block(bob), throwsA(isA<SignInRequired>()));
  });
}

class _Anonymous implements AuthService {
  @override
  UserProfile? get currentUser => null;
  @override
  List<SignInProvider> get providers => SignInProvider.values;
  @override
  Future<bool> signIn(SignInProvider provider) async => false;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {}
  @override
  Future<UserProfile?> rename(String displayName) async => null;
}

class _SignedIn extends _Anonymous {
  _SignedIn(this.id);
  final String id;
  @override
  UserProfile? get currentUser =>
      UserProfile(id: id, displayName: 'Me', createdAt: DateTime(2026));
}

class _MemoryBackend implements CommunityBackend {
  final reports = <(String, String, String)>[];
  final blocks = <String>{};

  @override
  Future<void> reportContent(
          ReportTarget target, String targetId, String reason) async =>
      reports.add((target.name, targetId, reason));
  @override
  Future<List<String>> blockedUsers(String userId) async => [...blocks];
  @override
  Future<void> blockUser(String userId, String blockedId) async =>
      blocks.add(blockedId);
  @override
  Future<void> unblockUser(String userId, String blockedId) async =>
      blocks.remove(blockedId);

  @override
  Future<List<UserProfile>> users() async => [];
  @override
  Future<void> saveUser(UserProfile user) async {}
  @override
  Future<List<CommunitySpot>> spots() async => [];
  @override
  Future<void> addSpot(CommunitySpot spot) async {}
  @override
  Future<void> updateSpot(CommunitySpot spot) async {}
  @override
  Future<void> deleteSpot(String spotId) async {}
  @override
  Future<List<SpotReview>> reviews() async => [];
  @override
  Future<void> saveReview(SpotReview review) async {}
  @override
  Future<List<SpotPhoto>> photos() async => [];
  @override
  Future<void> addPhoto(SpotPhoto photo) async {}
  @override
  Future<List<ExistenceVote>> votes() async => [];
  @override
  Future<void> addVote(ExistenceVote vote) async {}
  @override
  Future<List<ClosureReport>> closureReports() async => [];
  @override
  Future<void> addClosureReport(ClosureReport report) async {}
  @override
  Future<List<FeatureVote>> featureVotes() async => [];
  @override
  Future<void> addFeatureVote(FeatureVote vote) async {}
}
