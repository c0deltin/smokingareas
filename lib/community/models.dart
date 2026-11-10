import 'package:latlong2/latlong.dart';

/// A (local) user of the community features.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final DateTime createdAt;

  UserProfile copyWith({String? displayName}) => UserProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        displayName: j['displayName'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A smoking area reported by a user (not contained in any official or OSM
/// data set).
class CommunitySpot {
  const CommunitySpot({
    required this.id,
    required this.position,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.indoor,
    this.covered,
    this.publicAccess,
    this.accessNote,
    this.category = 'smoking',
    this.wheelchair,
    this.changingTable,
  });

  /// Always starts with `community:`.
  final String id;
  final LatLng position;
  final String name;
  final String? description;
  final bool? indoor;
  final bool? covered;

  /// Reachable without ticket, entrance fee or purchase. `false` e.g. for a
  /// smoking room on a station platform or inside a sight.
  final bool? publicAccess;

  /// How to get there when it is not public ("nur mit Bahnticket" …).
  final String? accessNote;

  /// `smoking` or `toilet` (name of a `SpotCategory`).
  final String category;

  /// Toilets: wheelchair accessible / baby changing table.
  final bool? wheelchair;
  final bool? changingTable;
  final String createdBy;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': position.latitude,
        'lon': position.longitude,
        'name': name,
        if (description != null) 'description': description,
        if (indoor != null) 'indoor': indoor,
        if (covered != null) 'covered': covered,
        if (publicAccess != null) 'publicAccess': publicAccess,
        if (accessNote != null) 'accessNote': accessNote,
        if (category != 'smoking') 'category': category,
        if (wheelchair != null) 'wheelchair': wheelchair,
        if (changingTable != null) 'changingTable': changingTable,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CommunitySpot.fromJson(Map<String, dynamic> j) => CommunitySpot(
        id: j['id'] as String,
        position: LatLng(
          (j['lat'] as num).toDouble(),
          (j['lon'] as num).toDouble(),
        ),
        name: j['name'] as String,
        description: j['description'] as String?,
        indoor: j['indoor'] as bool?,
        covered: j['covered'] as bool?,
        publicAccess: j['publicAccess'] as bool?,
        accessNote: j['accessNote'] as String?,
        category: j['category'] as String? ?? 'smoking',
        wheelchair: j['wheelchair'] as bool?,
        changingTable: j['changingTable'] as bool?,
        createdBy: j['createdBy'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A star rating (1–5) with optional comment. One per user and spot; a new
/// rating of the same user replaces the old one.
class SpotReview {
  const SpotReview({
    required this.spotId,
    required this.userId,
    required this.stars,
    required this.createdAt,
    this.comment,
  }) : assert(stars >= 1 && stars <= 5);

  /// Id of any visible smoking area (`osm:…`, `kyoto:…`, `community:…`).
  final String spotId;
  final String userId;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'spotId': spotId,
        'userId': userId,
        'stars': stars,
        if (comment != null) 'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SpotReview.fromJson(Map<String, dynamic> j) => SpotReview(
        spotId: j['spotId'] as String,
        userId: j['userId'] as String,
        stars: j['stars'] as int,
        comment: j['comment'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A photo of a spot. [storageKey] is resolved by a [PhotoStorage] adapter
/// (a local file today, an object-storage URL with a backend later).
class SpotPhoto {
  const SpotPhoto({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.storageKey,
    required this.createdAt,
  });

  final String id;
  final String spotId;
  final String userId;
  final String storageKey;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'spotId': spotId,
        'userId': userId,
        'storageKey': storageKey,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SpotPhoto.fromJson(Map<String, dynamic> j) => SpotPhoto(
        id: j['id'] as String,
        spotId: j['spotId'] as String,
        userId: j['userId'] as String,
        storageKey: j['storageKey'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// "Gibt es noch" (exists = true) / "Gibt es nicht mehr" (exists = false).
/// Only the latest vote of each user counts.
class ExistenceVote {
  const ExistenceVote({
    required this.spotId,
    required this.userId,
    required this.exists,
    required this.createdAt,
  });

  final String spotId;
  final String userId;
  final bool exists;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'spotId': spotId,
        'userId': userId,
        'exists': exists,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExistenceVote.fromJson(Map<String, dynamic> j) => ExistenceVote(
        spotId: j['spotId'] as String,
        userId: j['userId'] as String,
        exists: j['exists'] as bool,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
