import 'package:latlong2/latlong.dart';

/// A single designated smoking area (喫煙所 / 喫煙場所).
class SmokingArea {
  const SmokingArea({
    required this.id,
    required this.position,
    required this.source,
    this.name,
    this.tags = const {},
  });

  /// Globally unique id, e.g. `osm:node/123456`.
  final String id;
  final LatLng position;

  /// Human readable name of the data source (e.g. "OpenStreetMap").
  final String source;
  final String? name;

  /// Raw attributes delivered by the source (OSM tags, open data columns …).
  final Map<String, String> tags;

  double get latitude => position.latitude;
  double get longitude => position.longitude;

  /// Best effort display title.
  String get title {
    final n = name ?? tags['name:en'] ?? tags['name:ja'];
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return 'Raucherbereich';
  }

  /// Whether the smoking area is indoors (smoking room) or outdoors.
  bool? get isIndoor {
    final indoor = tags['indoor'];
    if (indoor == 'yes' || indoor == 'room') return true;
    if (indoor == 'no') return false;
    if (tags['smoking'] == 'isolated') return true;
    final kind = tags['official:kind'] ?? '';
    if (kind.contains('屋内')) return true;
    if (kind.contains('屋外')) return false;
    return null;
  }

  /// Entry comes from an official municipal list.
  bool get isOfficial => tags['official'] == 'yes';

  /// Position was derived from a street address (accuracy ~10–50 m) and
  /// could not be matched with a precisely mapped OSM point.
  bool get isApproximate => tags['geocoded'] == 'yes';

  String? get address => tags['addr:full'];

  /// OSM element (e.g. `node/123`) if this entry is or contains OSM data.
  String? get osmElement {
    if (id.startsWith('osm:')) return id.substring(4);
    return tags['osm:element'];
  }

  /// Web page of the official source, if any.
  String? get officialUrl => tags['official:url'];

  bool? get isCovered {
    final covered = tags['covered'] ?? tags['shelter'];
    if (covered == 'yes') return true;
    if (covered == 'no') return false;
    return null;
  }

  bool? get requiresFee {
    final fee = tags['fee'];
    if (fee == null) return null;
    return fee != 'no';
  }

  String? get openingHours => tags['opening_hours'];

  /// Number of smoking rooms combined in this entry (same building).
  int get roomCount => int.tryParse(tags['official:rooms'] ?? '') ?? 1;
  String? get operator => tags['operator'];
  String? get description => tags['description'] ?? tags['note'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': latitude,
        'lon': longitude,
        'source': source,
        if (name != null) 'name': name,
        'tags': tags,
      };

  factory SmokingArea.fromJson(Map<String, dynamic> json) => SmokingArea(
        id: json['id'] as String,
        position: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lon'] as num).toDouble(),
        ),
        source: json['source'] as String,
        name: json['name'] as String?,
        tags: (json['tags'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
      );

  @override
  bool operator ==(Object other) => other is SmokingArea && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
