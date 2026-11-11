import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/community/server_backend.dart';
import 'package:smoking_areas/community/server_rows.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/ui/sign_in_sheet.dart';

/// Server-like auth: anonymous until [signIn].
class FakeAuth implements AuthService {
  UserProfile? user;
  int signIns = 0;

  @override
  UserProfile? get currentUser => user;
  @override
  List<SignInProvider> get providers => SignInProvider.values;
  @override
  Future<bool> signIn(SignInProvider provider) async {
    signIns++;
    user = UserProfile(
        id: 'u1', displayName: 'Aiko', createdAt: DateTime(2026, 11, 11));
    return true;
  }

  @override
  Future<void> signOut() async => user = null;
  @override
  Future<void> deleteAccount() async => user = null;
  @override
  Future<UserProfile?> rename(String displayName) async => user;
}

const spot = SmokingArea(
  id: 'osm:node/1',
  position: LatLng(35.69, 139.70),
  source: 'OSM',
);

void main() {
  late Directory tmp;
  late FakeAuth auth;
  late CommunityService community;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('signin');
    auth = FakeAuth();
    community = CommunityService(
      backend: LocalCommunityBackend(() async => tmp),
      photos: LocalPhotoStorage(() async => tmp),
      auth: auth,
    );
    await community.init();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('anonymous users', () {
    test('can read but not contribute', () async {
      expect(community.isSignedIn, isFalse);
      expect(community.ratingFor(spot).count, 0);
      expect(community.myVote(spot), isNull);
      await expectLater(community.rate(spot, 4), throwsA(isA<SignInRequired>()));
      await expectLater(community.vote(spot, exists: false),
          throwsA(isA<SignInRequired>()));
      await expectLater(community.reportClosure(spot, closed: true),
          throwsA(isA<SignInRequired>()));
      await expectLater(
          community.reportSpot(position: spot.position, name: 'X'),
          throwsA(isA<SignInRequired>()));
    });

    test('contribute after signing in', () async {
      await community.signIn(SignInProvider.google);
      await community.rate(spot, 4);
      expect(community.ratingFor(spot).mine, 4);
      await community.signOut();
      expect(community.ratingFor(spot).mine, isNull);
      expect(community.ratingFor(spot).count, 1);
    });
  });

  Future<void> pumpButton(WidgetTester tester, Future<void> Function() onTap) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => contribute(context, community, onTap),
              child: const Text('Rate'),
            ),
          ),
        ),
      ));

  testWidgets('a contribution asks to sign in; staying anonymous cancels it',
      (tester) async {
    var saved = false;
    await pumpButton(tester, () async => saved = true);
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);

    await tester.tap(find.text('Continue without account'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(find.text('Sign in with Google'), findsNothing);
  });

  testWidgets('signing in from the sheet continues the contribution',
      (tester) async {
    var saved = false;
    await pumpButton(tester, () async => saved = true);
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(auth.signIns, 1);
    expect(saved, isTrue);
  });

  testWidgets('failures are shown as a short message', (tester) async {
    auth.user = UserProfile(id: 'u1', displayName: 'A', createdAt: DateTime(2026));
    await pumpButton(tester,
        () async => throw Exception('rate limit exceeded for votes'));
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Too many contributions'), findsOneWidget);
  });

  testWidgets('the initial sign-in prompt is shown only once', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const Scaffold();
      }),
    ));
    unawaited(maybeShowInitialSignIn(ctx, community, prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('Continue without account'), findsOneWidget);
    await tester.tap(find.text('Continue without account'));
    await tester.pumpAndSettle();

    unawaited(maybeShowInitialSignIn(ctx, community, prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('Continue without account'), findsNothing);
  });

  group('server rows', () {
    test('spot round trip; author and timestamps are not sent', () {
      final row = {
        'id': 'community:abc',
        'category': 'toilet',
        'lat': 35.69,
        'lon': 139.7,
        'name': 'Park toilet',
        'wheelchair': true,
        'not_same_as': ['osm:node/9'],
        'created_by': null,
        'created_at': '2026-11-11T10:00:00Z',
      };
      final s = ServerRows.spot(row);
      expect(s.createdBy, '');
      expect(s.category, 'toilet');
      final insert = ServerRows.spotInsert(s);
      expect(insert.containsKey('created_by'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
      expect(insert['not_same_as'], ['osm:node/9']);
    });

    test('a changed rating counts with its update time', () {
      final r = ServerRows.review({
        'spot_id': 'osm:node/1',
        'user_id': 'u1',
        'stars': 3,
        'created_at': '2026-11-01T00:00:00Z',
        'updated_at': '2026-11-10T00:00:00Z',
      });
      expect(r.createdAt, DateTime.utc(2026, 11, 10));
      expect(ServerRows.reviewUpsert(r).keys, {'spot_id', 'stars', 'comment'});
    });

    test('vote and closure inserts', () {
      final v = ExistenceVote(
          spotId: 's', userId: 'u', exists: false,
          createdAt: DateTime(2026), fingerprint: 'f');
      expect(ServerRows.voteInsert(v),
          {'spot_id': 's', 'exists': false, 'fingerprint': 'f'});
      final c = ClosureReport(
          spotId: 's', userId: 'u', closed: true,
          createdAt: DateTime(2026), until: DateTime.utc(2026, 12, 1));
      expect(ServerRows.closureInsert(c)['until'], '2026-12-01T00:00:00.000Z');
    });

    test('only well-formed photo paths are resolved', () {
      const id = '11111111-1111-1111-1111-111111111111';
      expect(ServerRows.isPhotoPath(ServerRows.photoPath(id, id)), isTrue);
      expect(ServerRows.isPhotoPath('../etc/passwd'), isFalse);
      expect(ServerRows.isPhotoPath('$id/../x.jpg'), isFalse);
    });
  });

  test('photos are re-encoded small and without metadata', () {
    final original = img.Image(width: 4000, height: 3000);
    original.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(35, 1);
    original.exif.imageIfd['Make'] = img.IfdValueAscii('Camera');
    final jpeg = Uint8List.fromList(img.encodeJpg(original));
    expect(img.decodeJpgExif(jpeg)?.isEmpty, isFalse);

    final out = reencodePhoto(jpeg);
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 1200);
    expect(img.decodeJpgExif(out)?.isEmpty ?? true, isTrue);
  });
}
