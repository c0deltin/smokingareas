import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Mapping between the community models and the rows of the server tables
/// (`supabase/migrations`). Pure, so it can be tested without a server.
///
/// Authors and timestamps are set by the database and are therefore never
/// sent; `updated_at` is used as the time of a row (a changed rating counts
/// as new).
class ServerRows {
  const ServerRows._();

  static DateTime _time(Object? v) =>
      v == null ? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.parse(v as String);

  static UserProfile profile(Map<String, dynamic> r) => UserProfile(
        id: r['id'] as String,
        displayName: r['display_name'] as String,
        createdAt: _time(r['created_at']),
      );

  static CommunitySpot spot(Map<String, dynamic> r) => CommunitySpot(
        id: r['id'] as String,
        position: LatLng(
            (r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()),
        name: r['name'] as String,
        description: r['description'] as String?,
        indoor: r['indoor'] as bool?,
        covered: r['covered'] as bool?,
        publicAccess: r['public_access'] as bool?,
        accessNote: r['access_note'] as String?,
        category: r['category'] as String? ?? 'smoking',
        wheelchair: r['wheelchair'] as bool?,
        changingTable: r['changing_table'] as bool?,
        waste: r['waste'] as String?,
        notSameAs: ((r['not_same_as'] as List?) ?? const []).cast<String>(),
        // Spots of deleted accounts stay without author.
        createdBy: r['created_by'] as String? ?? '',
        createdAt: _time(r['created_at']),
      );

  static Map<String, dynamic> spotInsert(CommunitySpot s) => {
        'id': s.id,
        'category': s.category,
        'lat': s.position.latitude,
        'lon': s.position.longitude,
        'name': s.name,
        'description': s.description,
        'indoor': s.indoor,
        'covered': s.covered,
        'public_access': s.publicAccess,
        'access_note': s.accessNote,
        'wheelchair': s.wheelchair,
        'changing_table': s.changingTable,
        // Only sent when set, so older databases keep accepting other spots.
        if (s.waste != null) 'waste': s.waste,
        'not_same_as': s.notSameAs,
      };

  /// Columns the author may change (the database only allows these).
  static Map<String, dynamic> spotUpdate(CommunitySpot s) => {
        'name': s.name,
        'description': s.description,
        'indoor': s.indoor,
        'covered': s.covered,
        'public_access': s.publicAccess,
        'access_note': s.accessNote,
        'wheelchair': s.wheelchair,
        'changing_table': s.changingTable,
        if (s.category == 'bin') 'waste': s.waste,
      };

  static SpotReview review(Map<String, dynamic> r) => SpotReview(
        spotId: r['spot_id'] as String,
        userId: r['user_id'] as String,
        stars: (r['stars'] as num).toInt(),
        comment: r['comment'] as String?,
        createdAt: _time(r['updated_at'] ?? r['created_at']),
      );

  static Map<String, dynamic> reviewUpsert(SpotReview r) => {
        'spot_id': r.spotId,
        'stars': r.stars,
        'comment': r.comment,
      };

  static SpotPhoto photo(Map<String, dynamic> r) => SpotPhoto(
        id: r['id'] as String,
        spotId: r['spot_id'] as String,
        userId: r['user_id'] as String,
        storageKey: r['storage_path'] as String,
        createdAt: _time(r['created_at']),
      );

  static Map<String, dynamic> photoInsert(SpotPhoto p) => {
        'id': p.id,
        'spot_id': p.spotId,
        'storage_path': p.storageKey,
      };

  static ExistenceVote vote(Map<String, dynamic> r) => ExistenceVote(
        spotId: r['spot_id'] as String,
        userId: r['user_id'] as String,
        exists: r['exists'] as bool,
        createdAt: _time(r['created_at']),
        fingerprint: r['fingerprint'] as String?,
      );

  static Map<String, dynamic> voteInsert(ExistenceVote v) => {
        'spot_id': v.spotId,
        'exists': v.exists,
        'fingerprint': v.fingerprint,
      };

  static ClosureReport closure(Map<String, dynamic> r) => ClosureReport(
        spotId: r['spot_id'] as String,
        userId: r['user_id'] as String,
        closed: r['closed'] as bool,
        note: r['note'] as String?,
        until: r['until'] == null ? null : _time(r['until']),
        createdAt: _time(r['created_at']),
        fingerprint: r['fingerprint'] as String?,
      );

  static Map<String, dynamic> closureInsert(ClosureReport c) => {
        'spot_id': c.spotId,
        'closed': c.closed,
        'note': c.note,
        'until': c.until?.toUtc().toIso8601String(),
        'fingerprint': c.fingerprint,
      };

  /// Storage path of a photo: `<user id>/<photo id>.jpg` (the bucket only
  /// accepts uploads into the own folder).
  static String photoPath(String userId, String photoId) =>
      '$userId/$photoId.jpg';

  static final _photoPath = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$');

  /// Only well-formed photo paths are downloaded or cached.
  static bool isPhotoPath(String key) => _photoPath.hasMatch(key);
}
