import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Storage adapter for all community data.
///
/// The interface is shaped like the tables of a multi-user database
/// (users, spots, reviews, photos, existence votes – every row carries the
/// `userId` of its author). Today [LocalCommunityBackend] keeps everything in
/// a JSON file on the device; later a server implementation (see
/// [RemoteCommunityBackend]) can be plugged in without touching the UI.
abstract class CommunityBackend {
  Future<List<UserProfile>> users();
  Future<void> saveUser(UserProfile user);

  Future<List<CommunitySpot>> spots();
  Future<void> addSpot(CommunitySpot spot);

  Future<List<SpotReview>> reviews();

  /// Inserts or replaces the review of `review.userId` for `review.spotId`.
  Future<void> saveReview(SpotReview review);

  Future<List<SpotPhoto>> photos();
  Future<void> addPhoto(SpotPhoto photo);

  Future<List<ExistenceVote>> votes();

  /// Votes are append-only (history); the policy uses the latest per user.
  Future<void> addVote(ExistenceVote vote);
}

/// Local, single-device implementation: one JSON document with one list per
/// "table", written atomically after every change.
class LocalCommunityBackend implements CommunityBackend {
  LocalCommunityBackend(this._directory);

  /// Directory provider, e.g. `getApplicationSupportDirectory`.
  final Future<Directory> Function() _directory;

  static const schemaVersion = 1;

  _Tables? _tables;
  Future<_Tables>? _loading;
  Future<void> _writeQueue = Future.value();

  Future<File> _file() async {
    final dir = Directory('${(await _directory()).path}/community');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/db.json');
  }

  Future<_Tables> _db() async {
    if (_tables != null) return _tables!;
    return _loading ??= () async {
      final file = await _file();
      _Tables t;
      if (await file.exists()) {
        try {
          t = _Tables.fromJson(
              jsonDecode(await file.readAsString()) as Map<String, dynamic>);
        } catch (_) {
          // Corrupt file: keep a copy for diagnosis and start fresh.
          await file.copy('${file.path}.corrupt');
          t = _Tables();
        }
      } else {
        t = _Tables();
      }
      return _tables = t;
    }();
  }

  Future<void> _persist() {
    // Serialise writes so that concurrent mutations never interleave.
    return _writeQueue = _writeQueue.then((_) async {
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(_tables!.toJson()));
      await tmp.rename(file.path);
    });
  }

  @override
  Future<List<UserProfile>> users() async => List.of((await _db()).users);

  @override
  Future<void> saveUser(UserProfile user) async {
    final t = await _db();
    t.users.removeWhere((u) => u.id == user.id);
    t.users.add(user);
    await _persist();
  }

  @override
  Future<List<CommunitySpot>> spots() async => List.of((await _db()).spots);

  @override
  Future<void> addSpot(CommunitySpot spot) async {
    final t = await _db();
    t.spots.removeWhere((s) => s.id == spot.id);
    t.spots.add(spot);
    await _persist();
  }

  @override
  Future<List<SpotReview>> reviews() async => List.of((await _db()).reviews);

  @override
  Future<void> saveReview(SpotReview review) async {
    final t = await _db();
    t.reviews.removeWhere(
        (r) => r.spotId == review.spotId && r.userId == review.userId);
    t.reviews.add(review);
    await _persist();
  }

  @override
  Future<List<SpotPhoto>> photos() async => List.of((await _db()).photos);

  @override
  Future<void> addPhoto(SpotPhoto photo) async {
    (await _db()).photos.add(photo);
    await _persist();
  }

  @override
  Future<List<ExistenceVote>> votes() async => List.of((await _db()).votes);

  @override
  Future<void> addVote(ExistenceVote vote) async {
    (await _db()).votes.add(vote);
    await _persist();
  }
}

class _Tables {
  final List<UserProfile> users = [];
  final List<CommunitySpot> spots = [];
  final List<SpotReview> reviews = [];
  final List<SpotPhoto> photos = [];
  final List<ExistenceVote> votes = [];

  Map<String, dynamic> toJson() => {
        'schemaVersion': LocalCommunityBackend.schemaVersion,
        'users': users.map((e) => e.toJson()).toList(),
        'spots': spots.map((e) => e.toJson()).toList(),
        'reviews': reviews.map((e) => e.toJson()).toList(),
        'photos': photos.map((e) => e.toJson()).toList(),
        'votes': votes.map((e) => e.toJson()).toList(),
      };

  static _Tables fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> rows(String key) =>
        ((j[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return _Tables()
      ..users.addAll(rows('users').map(UserProfile.fromJson))
      ..spots.addAll(rows('spots').map(CommunitySpot.fromJson))
      ..reviews.addAll(rows('reviews').map(SpotReview.fromJson))
      ..photos.addAll(rows('photos').map(SpotPhoto.fromJson))
      ..votes.addAll(rows('votes').map(ExistenceVote.fromJson));
  }
}

/// Placeholder for the future server backend (REST/GraphQL, Firebase,
/// Supabase …). Every call throws until it is implemented; the app uses
/// [LocalCommunityBackend] meanwhile.
///
/// Expected server responsibilities, so the local rules can move there:
/// * authenticate users and set `userId` server side,
/// * enforce one review per (spotId, userId),
/// * evaluate the [ExistencePolicy] server side, rate-limit votes,
/// * store photos in object storage and return their URL as `storageKey`.
class RemoteCommunityBackend implements CommunityBackend {
  RemoteCommunityBackend({required this.baseUrl});

  final Uri baseUrl;

  Never _todo(String op) =>
      throw UnimplementedError('RemoteCommunityBackend.$op ($baseUrl)');

  @override
  Future<List<UserProfile>> users() async => _todo('users');
  @override
  Future<void> saveUser(UserProfile user) async => _todo('saveUser');
  @override
  Future<List<CommunitySpot>> spots() async => _todo('spots');
  @override
  Future<void> addSpot(CommunitySpot spot) async => _todo('addSpot');
  @override
  Future<List<SpotReview>> reviews() async => _todo('reviews');
  @override
  Future<void> saveReview(SpotReview review) async => _todo('saveReview');
  @override
  Future<List<SpotPhoto>> photos() async => _todo('photos');
  @override
  Future<void> addPhoto(SpotPhoto photo) async => _todo('addPhoto');
  @override
  Future<List<ExistenceVote>> votes() async => _todo('votes');
  @override
  Future<void> addVote(ExistenceVote vote) async => _todo('addVote');
}
