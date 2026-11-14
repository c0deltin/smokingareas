import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/smoking_area.dart';
import 'auth_service.dart';
import 'community_backend.dart';
import 'closure_policy.dart';
import 'existence_policy.dart';
import 'feature_policy.dart';
import 'local_migration.dart';
import 'models.dart';
import 'photo_storage.dart';

/// Aggregated star rating of one spot.
class RatingSummary {
  const RatingSummary({required this.average, required this.count, this.mine});

  final double average;
  final int count;

  /// Stars given by the current user, if any.
  final int? mine;

  static const empty = RatingSummary(average: 0, count: 0);
}

/// Facade for all community features (report, rate, photos, existence votes,
/// local user profiles). Holds the data in memory and writes through to the
/// [CommunityBackend] adapter.
class CommunityService extends ChangeNotifier {
  CommunityService({
    required this.backend,
    required this.photos,
    required this.auth,
    this.policy = const ExistencePolicy(),
    this.closurePolicy = const ClosurePolicy(),
    this.featurePolicy = const FeaturePolicy(),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final CommunityBackend backend;
  final PhotoStorage photos;
  final AuthService auth;
  final ExistencePolicy policy;
  final ClosurePolicy closurePolicy;
  final FeaturePolicy featurePolicy;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  List<UserProfile> _users = [];
  List<CommunitySpot> _spots = [];
  List<SpotReview> _reviews = [];
  List<SpotPhoto> _photos = [];
  List<ExistenceVote> _votes = [];
  List<ClosureReport> _closures = [];
  List<FeatureVote> _featureVotes = [];
  Map<String, List<ExistenceVote>>? _votesBySpot;
  Map<String, List<FeatureVote>>? _featureVotesBySpot;

  /// Users the current user blocked: their spots, ratings and photos are
  /// hidden for them (votes still count for everyone).
  Set<String> _blocked = {};
  Map<String, List<ClosureReport>>? _closuresBySpot;

  /// Error of the last [init]/[refresh] (e.g. offline), null when loaded.
  Object? loadError;

  /// Loads all community data. With a server backend this needs the
  /// network; on failure the previous data stays and [loadError] is set.
  Future<void> init() async {
    try {
      final results = await Future.wait([
        backend.users(),
        backend.spots(),
        backend.reviews(),
        backend.photos(),
        backend.votes(),
        backend.closureReports(),
        backend.featureVotes(),
      ]);
      _users = results[0] as List<UserProfile>;
      _spots = results[1] as List<CommunitySpot>;
      _reviews = results[2] as List<SpotReview>;
      _photos = results[3] as List<SpotPhoto>;
      _votes = results[4] as List<ExistenceVote>;
      _closures = results[5] as List<ClosureReport>;
      _featureVotes = results[6] as List<FeatureVote>;
      final me = auth.currentUser?.id;
      _blocked = me == null ? {} : {...await backend.blockedUsers(me)};
      loadError = null;
      _loadedAt = _now();
    } catch (e) {
      loadError = e;
    }
    _changed();
  }

  Future<void> refresh() => init();

  DateTime? _loadedAt;
  Future<void>? _refreshing;

  /// Reloads the community data when it is older than [maxAge] (e.g. when a
  /// spot is opened or the app comes back to the foreground).
  Future<void> refreshIfStale(
      {Duration maxAge = const Duration(minutes: 1)}) {
    final loaded = _loadedAt;
    if (loaded != null && _now().difference(loaded) < maxAge) {
      return Future.value();
    }
    return _refreshing ??= init().whenComplete(() {
      _refreshing = null;
    });
  }

  void _changed() {
    _votesBySpot = null;
    _closuresBySpot = null;
    _featureVotesBySpot = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------

  /// Null while the user is anonymous (reading only).
  UserProfile? get currentUser => auth.currentUser;
  bool get isSignedIn => auth.currentUser != null;
  List<SignInProvider> get signInProviders => auth.providers;
  List<UserProfile> get users => List.unmodifiable(_users);

  /// Development mode without a server: several local profiles.
  bool get hasLocalProfiles => auth is LocalAuthService;

  String _requireUserId() {
    final user = auth.currentUser;
    if (user == null) throw const SignInRequired();
    return user.id;
  }

  /// Returns false when the user cancelled.
  Future<bool> signIn(SignInProvider provider) async {
    final ok = await auth.signIn(provider);
    if (ok) await init();
    return ok;
  }

  Future<void> signOut() async {
    await auth.signOut();
    _blocked = {};
    _changed();
  }

  // ---------------------------------------------------------------------
  // Moderation: report content, block users
  // ---------------------------------------------------------------------

  Set<String> get blockedUsers => Set.unmodifiable(_blocked);
  bool isBlocked(String userId) => _blocked.contains(userId);

  /// Reports objectionable content to the moderators.
  Future<void> report(ReportTarget target, String targetId, String reason) {
    _requireUserId();
    return backend.reportContent(target, targetId, reason.trim());
  }

  /// Hides all spots, ratings and photos of [userId] for the current user.
  Future<void> block(String userId) async {
    final me = _requireUserId();
    if (userId == me || userId.isEmpty) return;
    await backend.blockUser(me, userId);
    _blocked.add(userId);
    _changed();
  }

  Future<void> unblock(String userId) async {
    final me = _requireUserId();
    await backend.unblockUser(me, userId);
    _blocked.remove(userId);
    _changed();
  }

  /// Uploads device-only data of earlier versions to the signed-in account.
  Future<MigrationResult> uploadLocalData(LocalDataMigration migration) async {
    final userId = _requireUserId();
    final result = await migration.upload(
        target: backend, targetPhotos: photos, userId: userId);
    await init();
    return result;
  }

  /// Deletes the account with all its ratings, photos, votes and closure
  /// reports; reported spots stay without author.
  Future<void> deleteAccount() async {
    await auth.deleteAccount();
    await init();
  }

  String userName(String userId) {
    for (final u in _users) {
      if (u.id == userId) return u.displayName;
    }
    return 'Unknown';
  }

  Future<void> createUser(String name) async {
    await (auth as LocalAuthService).createProfile(name);
    _users = await backend.users();
    _changed();
  }

  Future<void> switchUser(String userId) async {
    await (auth as LocalAuthService).switchTo(userId);
    _changed();
  }

  Future<void> renameCurrentUser(String name) async {
    await auth.rename(name);
    _users = await backend.users();
    _changed();
  }

  // ---------------------------------------------------------------------
  // Spot ids
  // ---------------------------------------------------------------------

  /// All ids under which data for [area] may have been stored. A spot that
  /// was rated as plain OSM point and later merged with an official entry
  /// keeps its ratings, photos and votes.
  static Set<String> keysFor(SmokingArea area) => area.allIds;

  // ---------------------------------------------------------------------
  // Community spots
  // ---------------------------------------------------------------------

  /// User-reported spots as map entries. Spots of a category this app
  /// version does not know are skipped.
  List<SmokingArea> get spotsAsAreas => [
    for (final s in _spots)
      if (!_blocked.contains(s.createdBy) &&
          SpotCategory.tryParse(s.category) != null)
        SmokingArea(
          id: s.id,
          position: s.position,
          source: 'Community',
          name: s.name,
          tags: {
            'community': 'yes',
            'community:by': userName(s.createdBy),
            if (s.createdBy.isNotEmpty) 'community:by_id': s.createdBy,
            'community:created': s.createdAt.toIso8601String(),
            if (s.indoor != null) 'indoor': s.indoor! ? 'yes' : 'no',
            if (s.covered != null) 'covered': s.covered! ? 'yes' : 'no',
            // OSM schema: access=yes / access=customers (ticket, entry …)
            if (s.publicAccess != null)
              'access': s.publicAccess! ? 'yes' : 'customers',
            if (s.accessNote != null) 'access:note': s.accessNote!,
            if (SpotCategory.tryParse(s.category) case final c?
                when c != SpotCategory.smoking)
              'amenity': c.amenity,
            if (s.waste != null) 'waste': s.waste!,
            if (s.bin != null) 'bin': s.bin! ? 'yes' : 'no',
            if (s.wheelchair != null)
              'wheelchair': s.wheelchair! ? 'yes' : 'no',
            if (s.changingTable != null)
              'changing_table': s.changingTable! ? 'yes' : 'no',
            if (s.notSameAs.isNotEmpty)
              'community:not_same_as': s.notSameAs.join(','),
            if (s.description != null) 'description': s.description!,
          },
        ),
  ];

  Future<CommunitySpot> reportSpot({
    required LatLng position,
    required String name,
    String? description,
    bool? indoor,
    bool? covered,
    bool? publicAccess,
    String? accessNote,
    SpotCategory category = SpotCategory.smoking,
    bool? wheelchair,
    bool? changingTable,
    Set<WasteType> waste = const {},
    bool? bin,
    File? photo,
    Iterable<String> notSameAs = const [],
  }) async {
    final userId = _requireUserId();
    final now = _now();
    final spot = CommunitySpot(
      id: 'community:${_uuid.v4()}',
      position: position,
      name: name.trim().isEmpty ? category.label : name.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      indoor: category == SpotCategory.smoking ? indoor : null,
      covered: category == SpotCategory.smoking ? covered : null,
      publicAccess: publicAccess,
      accessNote:
          publicAccess == false &&
              accessNote != null &&
              accessNote.trim().isNotEmpty
          ? accessNote.trim()
          : null,
      category: category.name,
      wheelchair: category == SpotCategory.toilet ? wheelchair : null,
      changingTable: category == SpotCategory.toilet ? changingTable : null,
      waste: category == SpotCategory.bin ? WasteType.format(waste) : null,
      bin: category == SpotCategory.bin ? null : bin,
      notSameAs: notSameAs.toList(),
      createdBy: userId,
      createdAt: now,
    );
    await backend.addSpot(spot);
    _spots.add(spot);
    // Reporting a spot counts as confirming that it exists.
    await _addVote(spot.id, true, now);
    _changed();
    // The photo uploads in the background (shown as pending on the spot).
    if (photo != null) _startUpload(spot.id, photo);
    return spot;
  }

  /// Places the current user reported, newest first.
  List<CommunitySpot> get mySpots {
    final me = currentUser?.id;
    if (me == null) return const [];
    return _spots.where((s) => s.createdBy == me).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Map entry of an own spot (for rating, votes and status).
  SmokingArea? areaOf(CommunitySpot spot) {
    for (final a in spotsAsAreas) {
      if (a.id == spot.id) return a;
    }
    return null;
  }

  CommunitySpot _own(String spotId) {
    final me = _requireUserId();
    final spot = _spots.firstWhere((s) => s.id == spotId);
    if (spot.createdBy != me) {
      throw StateError('Only the author can change this place.');
    }
    return spot;
  }

  /// Changes name, note and attributes of an own spot (not its position or
  /// category).
  Future<CommunitySpot> updateSpot(
    String spotId, {
    required String name,
    String? description,
    bool? indoor,
    bool? covered,
    bool? publicAccess,
    String? accessNote,
    bool? wheelchair,
    bool? changingTable,
    Set<WasteType> waste = const {},
    bool? bin,
  }) async {
    final old = _own(spotId);
    final toilet = old.category == SpotCategory.toilet.name;
    final smoking = old.category == SpotCategory.smoking.name;
    final isBin = old.category == SpotCategory.bin.name;
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final updated = CommunitySpot(
      id: old.id,
      position: old.position,
      name: clean(name) ?? old.name,
      description: clean(description),
      indoor: smoking ? indoor : null,
      covered: smoking ? covered : null,
      publicAccess: publicAccess,
      accessNote: publicAccess == false ? clean(accessNote) : null,
      category: old.category,
      wheelchair: toilet ? wheelchair : null,
      changingTable: toilet ? changingTable : null,
      waste: isBin ? WasteType.format(waste) : null,
      bin: isBin ? null : bin,
      notSameAs: old.notSameAs,
      createdBy: old.createdBy,
      createdAt: old.createdAt,
    );
    await backend.updateSpot(updated);
    _spots[_spots.indexOf(old)] = updated;
    _changed();
    return updated;
  }

  /// Deletes an own spot from the map.
  Future<void> deleteSpot(String spotId) async {
    final spot = _own(spotId);
    await backend.deleteSpot(spotId);
    _spots.remove(spot);
    _changed();
  }

  // ---------------------------------------------------------------------
  // Ratings
  // ---------------------------------------------------------------------

  List<SpotReview> reviewsFor(SmokingArea area) {
    final keys = keysFor(area);
    // One review per user – the newest across all ids of the spot.
    final byUser = <String, SpotReview>{};
    for (final r in _reviews) {
      if (!keys.contains(r.spotId) || _blocked.contains(r.userId)) continue;
      final prev = byUser[r.userId];
      if (prev == null || r.createdAt.isAfter(prev.createdAt)) {
        byUser[r.userId] = r;
      }
    }
    return byUser.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  RatingSummary ratingFor(SmokingArea area) {
    final reviews = reviewsFor(area);
    if (reviews.isEmpty) return RatingSummary.empty;
    final sum = reviews.fold<int>(0, (s, r) => s + r.stars);
    final me = currentUser?.id;
    final mine = reviews.where((r) => r.userId == me);
    return RatingSummary(
      average: sum / reviews.length,
      count: reviews.length,
      mine: mine.isEmpty ? null : mine.first.stars,
    );
  }

  Future<void> rate(SmokingArea area, int stars, {String? comment}) async {
    final review = SpotReview(
      spotId: area.id,
      userId: _requireUserId(),
      stars: stars.clamp(1, 5),
      comment: comment?.trim().isEmpty ?? true ? null : comment!.trim(),
      createdAt: _now(),
    );
    await backend.saveReview(review);
    _reviews.removeWhere(
      (r) => r.spotId == review.spotId && r.userId == review.userId,
    );
    _reviews.add(review);
    _changed();
  }

  // ---------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------

  List<SpotPhoto> photosFor(SmokingArea area) {
    final keys = keysFor(area);
    return _photos
        .where((p) => keys.contains(p.spotId) && !_blocked.contains(p.userId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<File?> photoFile(SpotPhoto photo) => photos.resolve(photo.storageKey);

  // Uploads run in the background; the UI shows them as pending thumbnails
  // (with progress, or an error to retry) instead of blocking.
  final List<PendingPhoto> _pending = [];

  /// Photos of [area] that are still uploading or failed to upload.
  List<PendingPhoto> pendingPhotosFor(SmokingArea area) {
    final keys = keysFor(area);
    return _pending.where((p) => keys.contains(p.spotId)).toList();
  }

  /// Starts uploading [file] for [area] and returns at once; the photo shows
  /// up as pending until it is stored (see [pendingPhotosFor]).
  PendingPhoto addPhoto(SmokingArea area, File file) {
    _requireUserId();
    return _startUpload(area.id, file);
  }

  PendingPhoto _startUpload(String spotId, File file) {
    final pending = PendingPhoto._(spotId, file);
    _pending.add(pending);
    _changed();
    unawaited(_runUpload(pending));
    return pending;
  }

  Future<void> _runUpload(PendingPhoto p) async {
    p._error = null;
    p._done = Completer<void>();
    _changed();
    try {
      await _addPhoto(p.spotId, p.file, _now());
      _pending.remove(p);
      p._done.complete();
    } catch (e) {
      p._error = e;
      p._done.complete();
    }
    _changed();
  }

  /// Tries a failed upload again.
  Future<void> retryPhoto(PendingPhoto p) {
    if (!p.failed) return p.done;
    unawaited(_runUpload(p));
    return p.done;
  }

  /// Gives up a failed upload.
  void discardPhoto(PendingPhoto p) {
    _pending.remove(p);
    _changed();
  }

  Future<void> _addPhoto(String spotId, File file, DateTime now) async {
    final userId = _requireUserId();
    final key = await photos.save(file);
    final photo = SpotPhoto(
      id: _uuid.v4(),
      spotId: spotId,
      userId: userId,
      storageKey: key,
      createdAt: now,
    );
    await backend.addPhoto(photo);
    _photos.add(photo);
  }

  // ---------------------------------------------------------------------
  // Existence votes (Waze-like)
  // ---------------------------------------------------------------------

  List<ExistenceVote> _votesFor(SmokingArea area) {
    final index = _votesBySpot ??= () {
      final m = <String, List<ExistenceVote>>{};
      for (final v in _votes) {
        (m[v.spotId] ??= []).add(v);
      }
      return m;
    }();
    return [for (final k in keysFor(area)) ...?index[k]];
  }

  List<ClosureReport> _closuresFor(SmokingArea area) {
    final index = _closuresBySpot ??= () {
      final m = <String, List<ClosureReport>>{};
      for (final r in _closures) {
        (m[r.spotId] ??= []).add(r);
      }
      return m;
    }();
    return [for (final k in keysFor(area)) ...?index[k]];
  }

  /// Votes cast for the current version of the spot's source data never
  /// expire; see [ExistencePolicy].
  ExistenceStatus statusFor(SmokingArea area) => policy.evaluate(
    _votesFor(area),
    now: _now(),
    currentFingerprint: area.sourceFingerprint,
  );

  /// Latest vote of the current user (null = not voted).
  bool? myVote(SmokingArea area) {
    final keys = keysFor(area);
    ExistenceVote? latest;
    for (final v in _votes) {
      if (v.userId != currentUser?.id || !keys.contains(v.spotId)) continue;
      if (latest == null || v.createdAt.isAfter(latest.createdAt)) latest = v;
    }
    return latest?.exists;
  }

  Future<void> vote(SmokingArea area, {required bool exists}) async {
    await _addVote(area.id, exists, _now(), area.sourceFingerprint);
    _changed();
  }

  Future<void> _addVote(
    String spotId,
    bool exists,
    DateTime now, [
    String? fingerprint,
  ]) async {
    final vote = ExistenceVote(
      spotId: spotId,
      userId: _requireUserId(),
      exists: exists,
      createdAt: now,
      fingerprint: fingerprint,
    );
    await backend.addVote(vote);
    _votes.add(vote);
  }

  // ---------------------------------------------------------------------
  // Features ("trash can here?")
  // ---------------------------------------------------------------------

  List<FeatureVote> _featureVotesFor(SmokingArea area) {
    final index = _featureVotesBySpot ??= () {
      final m = <String, List<FeatureVote>>{};
      for (final v in _featureVotes) {
        (m[v.spotId] ??= []).add(v);
      }
      return m;
    }();
    return [for (final k in keysFor(area)) ...?index[k]];
  }

  FeatureStatus featureStatus(SmokingArea area, SpotFeature feature) =>
      featurePolicy.evaluate(_featureVotesFor(area), feature, now: _now());

  /// Latest answer of the current user (null = not answered).
  bool? myFeatureVote(SmokingArea area, SpotFeature feature) {
    final me = currentUser?.id;
    if (me == null) return null;
    FeatureVote? latest;
    for (final v in _featureVotesFor(area)) {
      if (v.userId != me || v.feature != feature) continue;
      if (latest == null || v.createdAt.isAfter(latest.createdAt)) latest = v;
    }
    return latest?.value;
  }

  Future<void> voteFeature(
    SmokingArea area,
    SpotFeature feature, {
    required bool value,
  }) async {
    final vote = FeatureVote(
      spotId: area.id,
      userId: _requireUserId(),
      feature: feature,
      value: value,
      createdAt: _now(),
    );
    await backend.addFeatureVote(vote);
    _featureVotes.add(vote);
    _changed();
  }

  // ---------------------------------------------------------------------
  // Temporary closures
  // ---------------------------------------------------------------------

  ClosureStatus closureFor(SmokingArea area) => closurePolicy.evaluate(
    _closuresFor(area),
    now: _now(),
    currentFingerprint: area.sourceFingerprint,
    officiallyClosed: area.tags['official:closed'] == 'yes',
  );

  /// Latest active closure report of the current user (null = none).
  bool? myClosureReport(SmokingArea area) {
    final keys = keysFor(area);
    ClosureReport? latest;
    for (final r in _closures) {
      if (r.userId != currentUser?.id || !keys.contains(r.spotId)) continue;
      if (latest == null || r.createdAt.isAfter(latest.createdAt)) latest = r;
    }
    return latest?.closed;
  }

  Future<void> reportClosure(
    SmokingArea area, {
    required bool closed,
    String? note,
    DateTime? until,
  }) async {
    final report = ClosureReport(
      spotId: area.id,
      userId: _requireUserId(),
      closed: closed,
      note: closed && (note?.trim().isNotEmpty ?? false) ? note!.trim() : null,
      until: closed ? until : null,
      createdAt: _now(),
      fingerprint: area.sourceFingerprint,
    );
    await backend.addClosureReport(report);
    _closures.add(report);
    _changed();
  }

  /// Applies community state to a map entry: feature answers (trash can)
  /// and closure reports. A "reopened" majority also overrides a closure
  /// flag that came with official data.
  SmokingArea annotate(SmokingArea area) =>
      _annotateClosure(_annotateFeatures(area));

  /// The community's verdict on features (e.g. `bin=yes`) wins over the
  /// source data; a tie keeps the source value.
  SmokingArea _annotateFeatures(SmokingArea area) {
    if (area.category == SpotCategory.bin) return area;
    if (_featureVotesFor(area).isEmpty) return area;
    final bin = featureStatus(area, SpotFeature.bin).value;
    if (bin == null) return area;
    return area.withTags({'bin': bin ? 'yes' : 'no'});
  }

  SmokingArea _annotateClosure(SmokingArea area) {
    if (_closuresFor(area).isEmpty) return area;
    final status = closureFor(area);
    if (status.closed) {
      return area.withTags({
        'temporarily_closed': 'yes',
        if (status.note != null) 'temporarily_closed:note': status.note!,
        if (status.until != null)
          'temporarily_closed:until': status.until!.toIso8601String(),
        if (status.since != null)
          'temporarily_closed:since': status.since!.toIso8601String(),
      });
    }
    if (area.isTemporarilyClosed && status.reopenedReports > 0) {
      return area.withTags(
        const {},
        remove: {
          'temporarily_closed',
          'temporarily_closed:note',
          'temporarily_closed:until',
          'temporarily_closed:since',
        },
      );
    }
    return area;
  }

  /// Whether [area] is removed by the community (votes under all its ids
  /// count together).
  bool isHidden(SmokingArea area) =>
      _votesFor(area).isNotEmpty && statusFor(area).hidden;
}

/// A photo that is uploading in the background or failed to upload.
class PendingPhoto {
  PendingPhoto._(this.spotId, this.file);

  final String spotId;

  /// The picked file, shown as thumbnail until the upload is done.
  final File file;
  Object? _error;
  Completer<void> _done = Completer<void>();

  bool get failed => _error != null;
  Object? get error => _error;

  /// Completes when the current upload attempt has finished.
  Future<void> get done => _done.future;
}
