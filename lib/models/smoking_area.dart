import 'package:latlong2/latlong.dart';

import 'data_fingerprint.dart';

/// Kind of place shown on the map.
enum SpotCategory {
  /// Designated smoking area (喫煙所 / 喫煙場所).
  smoking,

  /// Public toilet (公衆トイレ), OSM `amenity=toilets`.
  toilet,

  /// Public trash can (ゴミ箱), OSM `amenity=waste_basket`. Reported by the
  /// community only.
  bin;

  /// Label for the UI.
  String get label => switch (this) {
        SpotCategory.smoking => 'Smoking area',
        SpotCategory.toilet => 'Public toilet',
        SpotCategory.bin => 'Trash can',
      };

  String get pluralLabel => switch (this) {
        SpotCategory.smoking => 'Smoking areas',
        SpotCategory.toilet => 'Toilets',
        SpotCategory.bin => 'Trash cans',
      };

  /// OSM `amenity` value of the category.
  String get amenity => switch (this) {
        SpotCategory.smoking => 'smoking_area',
        SpotCategory.toilet => 'toilets',
        SpotCategory.bin => 'waste_basket',
      };

  /// Category stored under [name] (community data), or null when unknown –
  /// e.g. a category added by a newer app version.
  static SpotCategory? tryParse(String name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// What a trash can takes (OSM `waste=*`): Japanese bins are usually
/// separated, many next to vending machines only take cans and PET bottles.
enum WasteType {
  trash('trash', 'General waste'),
  cans('cans', 'Cans'),
  bottles('plastic_bottles', 'PET bottles');

  const WasteType(this.osm, this.label);
  final String osm;
  final String label;

  /// Parses an OSM `waste` value such as `cans;plastic_bottles`.
  static Set<WasteType> parse(String? value) => {
        for (final part in (value ?? '').split(';'))
          for (final t in values)
            if (t.osm == part.trim()) t,
      };

  /// OSM `waste` value in a stable order, or null when [types] is empty.
  static String? format(Iterable<WasteType> types) {
    final set = types.toSet();
    if (set.isEmpty) return null;
    return [for (final t in values) if (set.contains(t)) t.osm].join(';');
  }
}

/// A single place on the map – a smoking area, a public toilet or a trash
/// can (see [category]). The class name is historic; attributes follow the
/// OSM tag schema, the category is derived from `amenity`.
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

  SpotCategory get category => switch (tags['amenity']) {
        'toilets' => SpotCategory.toilet,
        'waste_basket' => SpotCategory.bin,
        _ => SpotCategory.smoking,
      };

  bool get isToilet => category == SpotCategory.toilet;
  bool get isSmoking => category == SpotCategory.smoking;

  /// Trash cans: accepted waste (OSM `waste=*`), empty when unknown.
  Set<WasteType> get waste => WasteType.parse(tags['waste']);

  /// Smoking areas and toilets: a trash can is part of the spot (OSM
  /// `bin=yes`), null when unknown.
  bool? get hasBin => switch (tags['bin']) {
        'yes' => true,
        'no' => false,
        _ => null,
      };

  /// Shown when the user looks for trash cans: real trash cans and spots
  /// with one.
  bool offers(SpotCategory c) =>
      category == c || (c == SpotCategory.bin && hasBin == true);

  /// Best effort display title.
  String get title {
    final n = name ?? tags['name:en'] ?? tags['name:ja'];
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return category.label;
  }

  /// Wheelchair accessible (toilets: `wheelchair` / `toilets:wheelchair`).
  bool? get wheelchair {
    final v = tags['toilets:wheelchair'] ?? tags['wheelchair'];
    if (v == 'yes' || v == 'designated') return true;
    if (v == 'no') return false;
    return null;
  }

  /// Temporarily closed (construction, renovation …). Set by official data
  /// or by community reports; such spots stay visible but greyed out and do
  /// not trigger alerts.
  bool get isTemporarilyClosed => tags['temporarily_closed'] == 'yes';

  String? get closedNote => tags['temporarily_closed:note'];

  DateTime? get closedUntil =>
      DateTime.tryParse(tags['temporarily_closed:until'] ?? '');

  /// Copy with additional / replaced tags.
  SmokingArea withTags(Map<String, String> extra, {Set<String> remove = const {}}) =>
      SmokingArea(
        id: id,
        position: position,
        source: source,
        name: name,
        tags: {
          for (final e in tags.entries)
            if (!remove.contains(e.key)) e.key: e.value,
          ...extra,
        },
      );

  /// Baby changing table (`changing_table`).
  bool? get changingTable {
    final v = tags['changing_table'];
    if (v == 'yes') return true;
    if (v == 'no') return false;
    return null;
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

  /// Fingerprint of the source data this entry is based on (null for pure
  /// user reports). See `data_fingerprint.dart`.
  String? get sourceFingerprint => tags[fingerprintTag];

  /// Copy with the fingerprint of its OSM source data set (used for entries
  /// fetched from Overpass and for older caches without it).
  SmokingArea withOsmFingerprint() {
    if (tags.containsKey(fingerprintTag)) return this;
    final source = {
      for (final e in tags.entries)
        if (!isDerivedTag(e.key)) e.key: e.value,
    };
    return withTags(
        {fingerprintTag: dataFingerprint(position: position, fields: source)});
  }

  /// Every id this place has been known under: its own id, former ids from
  /// earlier data snapshots and ids of entries merged into it. Community data
  /// (ratings, photos, votes, closures) is looked up under all of them.
  Set<String> get allIds => {
        id,
        if (osmElement != null) 'osm:$osmElement',
        ...?tags['aliases']
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      };

  /// Web page of the official source, if any.
  String? get officialUrl => tags['official:url'];

  bool? get isCovered {
    final covered = tags['covered'] ?? tags['shelter'];
    if (covered == 'yes') return true;
    if (covered == 'no') return false;
    return null;
  }

  /// Publicly reachable (true), only with ticket / entry / purchase (false).
  bool? get isPublic {
    switch (tags['access']) {
      case 'yes' || 'public' || 'permissive':
        return true;
      case 'customers' || 'private' || 'no' || 'permit' || 'destination':
        return false;
    }
    return null;
  }

  String? get accessNote => tags['access:note'];

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
