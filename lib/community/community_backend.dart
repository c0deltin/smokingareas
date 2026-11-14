import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Storage adapter for all community data.
///
/// The interface is shaped like the tables of a multi-user database
/// (users, spots, reviews, photos, existence votes – every row carries the
/// `userId` of its author). [LocalCommunityBackend] keeps everything in a
/// JSON file on the device (development builds); `ServerCommunityBackend`
/// (server_backend.dart) is used when the server is configured.
abstract class CommunityBackend {
  Future<List<UserProfile>> users();
  Future<void> saveUser(UserProfile user);

  Future<List<CommunitySpot>> spots();
  Future<void> addSpot(CommunitySpot spot);

  /// Changes the details of an own reported spot (not its position).
  Future<void> updateSpot(CommunitySpot spot);

  /// Deletes an own reported spot.
  Future<void> deleteSpot(String spotId);

  Future<List<SpotReview>> reviews();

  /// Inserts or replaces the review of `review.userId` for `review.spotId`.
  Future<void> saveReview(SpotReview review);

  Future<List<SpotPhoto>> photos();
  Future<void> addPhoto(SpotPhoto photo);

  Future<List<ExistenceVote>> votes();

  /// Votes are append-only (history); the policy uses the latest per user.
  Future<void> addVote(ExistenceVote vote);

  /// Answers to "does this spot have …?" (append-only, see `FeaturePolicy`).
  Future<List<FeatureVote>> featureVotes();
  Future<void> addFeatureVote(FeatureVote vote);

  Future<List<ClosureReport>> closureReports();

  /// Append-only, like votes; see `ClosurePolicy`.
  Future<void> addClosureReport(ClosureReport report);

  /// Reports objectionable content to the moderators.
  Future<void> reportContent(
      ReportTarget target, String targetId, String reason);

  /// Users the current user has blocked (their content is hidden for them).
  Future<List<String>> blockedUsers(String userId);
  Future<void> blockUser(String userId, String blockedId);
  Future<void> unblockUser(String userId, String blockedId);
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
  Future<void> updateSpot(CommunitySpot spot) => addSpot(spot);

  @override
  Future<void> deleteSpot(String spotId) async {
    (await _db()).spots.removeWhere((s) => s.id == spotId);
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

  @override
  Future<List<ClosureReport>> closureReports() async =>
      List.of((await _db()).closures);

  @override
  Future<void> addClosureReport(ClosureReport report) async {
    (await _db()).closures.add(report);
    await _persist();
  }

  @override
  Future<List<FeatureVote>> featureVotes() async =>
      List.of((await _db()).featureVotes);

  @override
  Future<void> addFeatureVote(FeatureVote vote) async {
    (await _db()).featureVotes.add(vote);
    await _persist();
  }

  @override
  Future<void> reportContent(
      ReportTarget target, String targetId, String reason) async {
    (await _db()).reports.add({
      'target_type': target.name,
      'target_id': targetId,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _persist();
  }

  @override
  Future<List<String>> blockedUsers(String userId) async =>
      [...?(await _db()).blocks[userId]];

  @override
  Future<void> blockUser(String userId, String blockedId) async {
    final list = (await _db()).blocks.putIfAbsent(userId, () => []);
    if (!list.contains(blockedId)) list.add(blockedId);
    await _persist();
  }

  @override
  Future<void> unblockUser(String userId, String blockedId) async {
    (await _db()).blocks[userId]?.remove(blockedId);
    await _persist();
  }

  /// True when the device holds community data (e.g. from before accounts
  /// existed).
  Future<bool> get hasData async {
    final t = await _db();
    return t.spots.isNotEmpty ||
        t.reviews.isNotEmpty ||
        t.photos.isNotEmpty ||
        t.votes.isNotEmpty ||
        t.closures.isNotEmpty ||
        t.featureVotes.isNotEmpty;
  }

  /// Removes all community data from the device (after it was uploaded or
  /// discarded). Photo files are deleted separately by the caller.
  Future<void> clear() async {
    final t = await _db();
    t.spots.clear();
    t.reviews.clear();
    t.photos.clear();
    t.votes.clear();
    t.closures.clear();
    t.featureVotes.clear();
    t.reports.clear();
    t.blocks.clear();
    await _persist();
  }

  /// Removes rows once they were uploaded (resumable migration). For
  /// ratings, votes and closure reports all rows of the place go, since
  /// only the latest one was uploaded.
  Future<void> remove({
    CommunitySpot? spot,
    SpotPhoto? photo,
    String? reviewsOf,
    String? votesOf,
    String? closuresOf,
  }) async {
    final t = await _db();
    if (spot != null) t.spots.removeWhere((s) => s.id == spot.id);
    if (photo != null) t.photos.removeWhere((p) => p.id == photo.id);
    if (reviewsOf != null) t.reviews.removeWhere((r) => r.spotId == reviewsOf);
    if (votesOf != null) t.votes.removeWhere((v) => v.spotId == votesOf);
    if (closuresOf != null) {
      t.closures.removeWhere((c) => c.spotId == closuresOf);
    }
    await _persist();
  }
}

class _Tables {
  final List<UserProfile> users = [];
  final List<CommunitySpot> spots = [];
  final List<SpotReview> reviews = [];
  final List<SpotPhoto> photos = [];
  final List<ExistenceVote> votes = [];
  final List<ClosureReport> closures = [];
  final List<FeatureVote> featureVotes = [];
  final List<Map<String, dynamic>> reports = [];
  final Map<String, List<String>> blocks = {};

  Map<String, dynamic> toJson() => {
        'schemaVersion': LocalCommunityBackend.schemaVersion,
        'users': users.map((e) => e.toJson()).toList(),
        'spots': spots.map((e) => e.toJson()).toList(),
        'reviews': reviews.map((e) => e.toJson()).toList(),
        'photos': photos.map((e) => e.toJson()).toList(),
        'votes': votes.map((e) => e.toJson()).toList(),
        'closures': closures.map((e) => e.toJson()).toList(),
        'featureVotes': featureVotes.map((e) => e.toJson()).toList(),
        'reports': reports,
        'blocks': blocks,
      };

  static _Tables fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> rows(String key) =>
        ((j[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return _Tables()
      ..users.addAll(rows('users').map(UserProfile.fromJson))
      ..spots.addAll(rows('spots').map(CommunitySpot.fromJson))
      ..reviews.addAll(rows('reviews').map(SpotReview.fromJson))
      ..photos.addAll(rows('photos').map(SpotPhoto.fromJson))
      ..votes.addAll(rows('votes').map(ExistenceVote.fromJson))
      ..closures.addAll(rows('closures').map(ClosureReport.fromJson))
      ..featureVotes.addAll(
          rows('featureVotes').map(FeatureVote.fromJson).whereType<FeatureVote>())
      ..reports.addAll(rows('reports'))
      ..blocks.addAll({
        for (final e in ((j['blocks'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as List).cast<String>(),
      });
  }
}
