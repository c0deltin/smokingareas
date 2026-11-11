import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/sources/official_opendata_source.dart';

void main() {
  final snapshot = OfficialOpenDataSource(
      loader: () =>
          File('assets/opendata/official_smoking_areas.json').readAsString());

  Future<List<SmokingArea>> all() async {
    final out = <SmokingArea>[];
    for (final c in ['tokyo', 'osaka', 'kyoto', 'okayama']) {
      out.addAll(await snapshot.fetch(cityById(c)!.bounds));
    }
    return {for (final a in out) a.id: a}.values.toList();
  }

  test('official ids are unique and not row numbers', () async {
    final areas = await all();
    final ids = areas.map((a) => a.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    final positional = ids.where((id) {
      final local = id.substring(id.indexOf(':') + 1);
      // Kyoto's facility ids are real ids; everything else must not be a
      // plain row number any more.
      return RegExp(r'^\d{1,4}$').hasMatch(local);
    });
    expect(positional, isEmpty);
  });

  test('former ids are exposed as aliases', () async {
    final areas = await all();
    final shinjukuEast =
        areas.firstWhere((a) => a.title == '新宿駅東口公衆喫煙所');
    expect(shinjukuEast.id, isNot('tokyo_shinjuku:0'));
    expect(shinjukuEast.allIds, contains('tokyo_shinjuku:0'));
  });

  group('community data survives an id change', () {
    late Directory tmp;
    late CommunityService service;
    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('ids');
      SharedPreferences.setMockInitialValues({});
      final backend = LocalCommunityBackend(() async => tmp);
      // Data recorded with an older app version under the positional id.
      await backend.saveReview(SpotReview(
          spotId: 'tokyo_shinjuku:0',
          userId: 'u1',
          stars: 4,
          createdAt: DateTime.now()));
      for (final u in ['u1', 'u2', 'u3']) {
        await backend.addVote(ExistenceVote(
            spotId: 'tokyo_shinjuku:0',
            userId: u,
            exists: false,
            createdAt: DateTime.now()));
      }
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      service = CommunityService(
          backend: backend,
          photos: LocalPhotoStorage(() async => tmp),
          auth: auth);
      await service.init();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('ratings and "gone" votes apply to the entry with the new id',
        () async {
      final renamed = SmokingArea(
        id: 'tokyo_shinjuku:hcaa6a03e3f',
        position: const LatLng(35.693, 139.700),
        source: 'Bezirk Shinjuku',
        tags: const {'official': 'yes', 'aliases': 'tokyo_shinjuku:0'},
      );
      expect(service.ratingFor(renamed).count, 1);
      expect(service.ratingFor(renamed).average, 4);
      expect(service.isHidden(renamed), isTrue);
    });
  });
}
