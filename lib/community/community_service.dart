import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/smoking_area.dart';
import 'auth_service.dart';
import 'community_backend.dart';
import 'closure_policy.dart';
import 'existence_policy.dart';
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
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final CommunityBackend backend;
  final PhotoStorage photos;
  final AuthService auth;
  final ExistencePolicy policy;
  final ClosurePolicy closurePolicy;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  List<UserProfile> _users = [];
  List<CommunitySpot> _spots = [];
  List<SpotReview> _reviews = [];
  List<SpotPhoto> _photos = [];
  List<ExistenceVote> _votes = [];
  List<ClosureReport> _closures = [];
  Set<String>? _hiddenCache;

  Future<void> init() async {
    _users = await backend.users();
    _spots = await backend.spots();
    _reviews = await backend.reviews();
    _photos = await backend.photos();
    _votes = await backend.votes();
    _closures = await backend.closureReports();
    _changed();
  }

  void _changed() {
    _hiddenCache = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------

  UserProfile get currentUser => auth.currentUser;
  List<UserProfile> get users => List.unmodifiable(_users);

  String userName(String userId) {
    for (final u in _users) {
      if (u.id == userId) return u.displayName;
    }
    return 'Unbekannt';
  }

  Future<void> createUser(String name) async {
    await auth.createProfile(name);
    _users = await backend.users();
    _changed();
  }

  Future<void> switchUser(String userId) async {
    await auth.switchTo(userId);
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

  /// User-reported spots as map entries.
  List<SmokingArea> get spotsAsAreas => [
        for (final s in _spots)
          SmokingArea(
            id: s.id,
            position: s.position,
            source: 'Community',
            name: s.name,
            tags: {
              'community': 'yes',
              'community:by': userName(s.createdBy),
              'community:created': s.createdAt.toIso8601String(),
              if (s.indoor != null) 'indoor': s.indoor! ? 'yes' : 'no',
              if (s.covered != null) 'covered': s.covered! ? 'yes' : 'no',
              // OSM schema: access=yes / access=customers (ticket, entry …)
              if (s.publicAccess != null)
                'access': s.publicAccess! ? 'yes' : 'customers',
              if (s.accessNote != null) 'access:note': s.accessNote!,
              if (s.category == SpotCategory.toilet.name) 'amenity': 'toilets',
              if (s.wheelchair != null)
                'wheelchair': s.wheelchair! ? 'yes' : 'no',
              if (s.changingTable != null)
                'changing_table': s.changingTable! ? 'yes' : 'no',
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
    File? photo,
  }) async {
    final now = _now();
    final spot = CommunitySpot(
      id: 'community:${_uuid.v4()}',
      position: position,
      name: name.trim().isEmpty ? category.label : name.trim(),
      description:
          description?.trim().isEmpty ?? true ? null : description!.trim(),
      indoor: category == SpotCategory.smoking ? indoor : null,
      covered: category == SpotCategory.smoking ? covered : null,
      publicAccess: publicAccess,
      accessNote: publicAccess == false &&
              accessNote != null &&
              accessNote.trim().isNotEmpty
          ? accessNote.trim()
          : null,
      category: category.name,
      wheelchair: category == SpotCategory.toilet ? wheelchair : null,
      changingTable: category == SpotCategory.toilet ? changingTable : null,
      createdBy: currentUser.id,
      createdAt: now,
    );
    await backend.addSpot(spot);
    _spots.add(spot);
    // Reporting a spot counts as confirming that it exists.
    await _addVote(spot.id, true, now);
    if (photo != null) await _addPhoto(spot.id, photo, now);
    _changed();
    return spot;
  }

  // ---------------------------------------------------------------------
  // Ratings
  // ---------------------------------------------------------------------

  List<SpotReview> reviewsFor(SmokingArea area) {
    final keys = keysFor(area);
    // One review per user – the newest across all ids of the spot.
    final byUser = <String, SpotReview>{};
    for (final r in _reviews) {
      if (!keys.contains(r.spotId)) continue;
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
    final mine = reviews.where((r) => r.userId == currentUser.id);
    return RatingSummary(
      average: sum / reviews.length,
      count: reviews.length,
      mine: mine.isEmpty ? null : mine.first.stars,
    );
  }

  Future<void> rate(SmokingArea area, int stars, {String? comment}) async {
    final review = SpotReview(
      spotId: area.id,
      userId: currentUser.id,
      stars: stars.clamp(1, 5),
      comment: comment?.trim().isEmpty ?? true ? null : comment!.trim(),
      createdAt: _now(),
    );
    await backend.saveReview(review);
    _reviews.removeWhere(
        (r) => r.spotId == review.spotId && r.userId == review.userId);
    _reviews.add(review);
    _changed();
  }

  // ---------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------

  List<SpotPhoto> photosFor(SmokingArea area) {
    final keys = keysFor(area);
    return _photos.where((p) => keys.contains(p.spotId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<File?> photoFile(SpotPhoto photo) => photos.resolve(photo.storageKey);

  Future<void> addPhoto(SmokingArea area, File file) async {
    await _addPhoto(area.id, file, _now());
    _changed();
  }

  Future<void> _addPhoto(String spotId, File file, DateTime now) async {
    final key = await photos.save(file);
    final photo = SpotPhoto(
      id: _uuid.v4(),
      spotId: spotId,
      userId: currentUser.id,
      storageKey: key,
      createdAt: now,
    );
    await backend.addPhoto(photo);
    _photos.add(photo);
  }

  // ---------------------------------------------------------------------
  // Existence votes (Waze-like)
  // ---------------------------------------------------------------------

  ExistenceStatus statusFor(SmokingArea area) {
    final keys = keysFor(area);
    return policy.evaluate(
      _votes.where((v) => keys.contains(v.spotId)),
      now: _now(),
    );
  }

  /// Latest vote of the current user (null = not voted).
  bool? myVote(SmokingArea area) {
    final keys = keysFor(area);
    ExistenceVote? latest;
    for (final v in _votes) {
      if (v.userId != currentUser.id || !keys.contains(v.spotId)) continue;
      if (latest == null || v.createdAt.isAfter(latest.createdAt)) latest = v;
    }
    return latest?.exists;
  }

  Future<void> vote(SmokingArea area, {required bool exists}) async {
    await _addVote(area.id, exists, _now());
    _changed();
  }

  Future<void> _addVote(String spotId, bool exists, DateTime now) async {
    final vote = ExistenceVote(
      spotId: spotId,
      userId: currentUser.id,
      exists: exists,
      createdAt: now,
    );
    await backend.addVote(vote);
    _votes.add(vote);
  }

  // ---------------------------------------------------------------------
  // Temporary closures
  // ---------------------------------------------------------------------

  ClosureStatus closureFor(SmokingArea area) {
    final keys = keysFor(area);
    return closurePolicy.evaluate(
      _closures.where((r) => keys.contains(r.spotId)),
      now: _now(),
    );
  }

  /// Latest active closure report of the current user (null = none).
  bool? myClosureReport(SmokingArea area) {
    final keys = keysFor(area);
    ClosureReport? latest;
    for (final r in _closures) {
      if (r.userId != currentUser.id || !keys.contains(r.spotId)) continue;
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
      userId: currentUser.id,
      closed: closed,
      note: closed && (note?.trim().isNotEmpty ?? false) ? note!.trim() : null,
      until: closed ? until : null,
      createdAt: _now(),
    );
    await backend.addClosureReport(report);
    _closures.add(report);
    _changed();
  }

  /// Applies community closure reports to a map entry. A "reopened" majority
  /// also overrides a closure flag that came with official data.
  SmokingArea annotate(SmokingArea area) {
    final keys = keysFor(area);
    if (!_closures.any((r) => keys.contains(r.spotId))) return area;
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
      return area.withTags(const {}, remove: {
        'temporarily_closed',
        'temporarily_closed:note',
        'temporarily_closed:until',
        'temporarily_closed:since',
      });
    }
    return area;
  }

  /// Ids of spots removed by the community.
  Set<String> get hiddenIds => _hiddenCache ??= () {
        final bySpot = <String, List<ExistenceVote>>{};
        for (final v in _votes) {
          (bySpot[v.spotId] ??= []).add(v);
        }
        final now = _now();
        return {
          for (final e in bySpot.entries)
            if (policy.evaluate(e.value, now: now).hidden) e.key,
        };
      }();

  /// Whether [area] is removed by the community (checks all its ids, and
  /// combines the votes cast under each of them).
  bool isHidden(SmokingArea area) {
    final keys = keysFor(area);
    if (keys.length == 1) return hiddenIds.contains(area.id);
    return statusFor(area).hidden;
  }
}
