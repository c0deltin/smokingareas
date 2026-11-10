import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../data/cities.dart';
import '../models/city.dart';
import '../models/smoking_area.dart';
import '../sources/official_opendata_source.dart';
import '../sources/overpass_source.dart';
import '../sources/smoking_area_source.dart';

/// Result of loading the smoking areas of one city.
class CityAreas {
  CityAreas({
    required this.city,
    required this.areas,
    required this.fetchedAt,
    this.fromCache = false,
    this.errors = const [],
  });

  final City city;

  /// All visible (merged) smoking areas inside the city's download area.
  final List<SmokingArea> areas;
  final DateTime fetchedAt;
  final bool fromCache;

  /// Non fatal errors of individual sources.
  final List<String> errors;
}

/// Holds one merged data set of smoking areas for all of Japan.
///
/// * Bundled sources (the official municipal snapshot) are available
///   immediately after [warmUp] – for every city, without network.
/// * Live sources (OpenStreetMap) are fetched per city, cached on disk per
///   source and loaded from that cache at start-up as well.
/// * [allVisible] combines everything into one list without duplicates, so the
///   map and the proximity alerts always see all known data at once.
class SmokingAreaRepository extends ChangeNotifier {
  SmokingAreaRepository({
    List<SmokingAreaSource>? sources,
    Future<Directory> Function()? cacheDirectory,
    this.maxAge = const Duration(days: 7),
  })  : sources = sources ?? [OfficialOpenDataSource(), OverpassSource()],
        _cacheDirectory = cacheDirectory ?? getApplicationSupportDirectory;

  final List<SmokingAreaSource> sources;
  final Future<Directory> Function() _cacheDirectory;
  final Duration maxAge;

  /// Whole of Japan – used to read bundled sources completely.
  static const japan = GeoBounds(south: 20, west: 122, north: 46, east: 154);

  /// Distance below which two points of different sources are considered the
  /// same smoking area.
  static const double duplicateThresholdMeters = 8;

  /// Maximum distance at which an official entry and an OSM entry are treated
  /// as the same smoking area. Official coordinates from a CSV are precise;
  /// geocoded street addresses can be a few dozen metres off.
  static const double mergeRadiusPrecise = 25;
  static const double mergeRadiusGeocoded = 50;

  /// Version of the per-city cache content (2 = OSM incl. public toilets).
  static const int cacheSchema = 2;

  List<SmokingArea> _bundled = const [];
  Future<void>? _bundledLoading;
  final List<String> _bundledErrors = [];
  final Map<String, _CacheSnapshot> _cities = {};
  final Map<String, Future<CityAreas>> _inFlight = {};
  List<SmokingArea>? _visible;
  bool _warmedUp = false;

  List<String> get attributions =>
      sources.map((s) => s.attribution).toList(growable: false);

  Iterable<SmokingAreaSource> get _liveSources =>
      sources.where((s) => !s.isBundled);

  // ---------------------------------------------------------------------
  // Visible data
  // ---------------------------------------------------------------------

  /// Every known smoking area (all cities, all sources), merged.
  List<SmokingArea> get allVisible => _visible ??= merge([
        ..._bundled,
        for (final snap in _cities.values)
          for (final list in snap.raw.values) ...list,
        ..._community,
      ]).where((a) => !_isHidden(a)).toList();

  // Community data (user reports + crowd moderation), see [setCommunity].
  List<SmokingArea> _community = const [];
  bool Function(SmokingArea) _isHidden = _never;
  static bool _never(SmokingArea _) => false;

  /// Adds user-reported spots to the merged data set and removes every spot
  /// for which [isHidden] is true (reported as gone by the community).
  void setCommunity({
    required List<SmokingArea> spots,
    required bool Function(SmokingArea) isHidden,
  }) {
    _community = spots;
    _isHidden = isHidden;
    _changed();
  }

  /// Alias kept for the proximity monitor.
  Iterable<SmokingArea> get allLoaded => allVisible;

  List<SmokingArea> areasIn(GeoBounds bounds) =>
      allVisible.where((a) => bounds.contains(a.position)).toList();

  /// What is known about [cityId] right now, without any network access.
  CityAreas? cached(String cityId) {
    final city = cityById(cityId);
    if (city == null) return null;
    final snap = _cities[cityId];
    if (snap == null && _bundled.isEmpty) return null;
    return CityAreas(
      city: city,
      areas: areasIn(city.bounds),
      fetchedAt: snap?.fetchedAt ?? DateTime(2000),
      fromCache: true,
    );
  }

  void _changed() {
    _visible = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Start-up
  // ---------------------------------------------------------------------

  /// Loads the bundled snapshot and every city cached on disk. Fast and
  /// offline – call before showing the map so all data is visible at once.
  Future<void> warmUp() async {
    if (_warmedUp) return;
    _warmedUp = true;
    await _ensureBundled();
    for (final city in kCities) {
      if (_cities.containsKey(city.id)) continue;
      final snap = await _readCache(city);
      if (snap != null) _cities[city.id] = snap;
    }
    _changed();
  }

  Future<void> _ensureBundled() => _bundledLoading ??= () async {
        final out = <SmokingArea>[];
        for (final s in sources.where((s) => s.isBundled)) {
          try {
            out.addAll(await s.fetch(japan));
          } catch (e) {
            _bundledErrors.add('${s.displayName}: $e');
          }
        }
        _bundled = out;
        _changed();
      }();

  // ---------------------------------------------------------------------
  // Loading live data
  // ---------------------------------------------------------------------

  /// Refreshes the live data of [city]. Uses the disk cache if it is younger
  /// than [maxAge] unless [forceRefresh] is set. When a live source fails,
  /// its previously cached data is kept.
  Future<CityAreas> load(City city, {bool forceRefresh = false}) {
    return _inFlight[city.id] ??=
        _load(city, forceRefresh).whenComplete(() {
      // Block body on purpose: returning the removed future would make
      // whenComplete wait on itself.
      _inFlight.remove(city.id);
    });
  }

  /// Loads all cities whose area contains [position].
  Future<List<SmokingArea>> loadAround(LatLng position) async {
    final cities = citiesContaining(position);
    for (final c in cities) {
      try {
        await load(c);
      } catch (_) {
        // Ignore – proximity checks just use what is available.
      }
    }
    return allVisible;
  }

  bool _isStale(DateTime fetchedAt) =>
      DateTime.now().difference(fetchedAt) > maxAge;

  Future<CityAreas> _load(City city, bool forceRefresh) async {
    await _ensureBundled();
    final disk = _cities[city.id] ?? await _readCache(city);
    if (!forceRefresh && disk != null && !_isStale(disk.fetchedAt)) {
      if (!_cities.containsKey(city.id)) {
        _cities[city.id] = disk;
        _changed();
      }
      return CityAreas(
        city: city,
        areas: areasIn(city.bounds),
        fetchedAt: disk.fetchedAt,
        fromCache: true,
      );
    }

    final bounds = city.bounds;
    final errors = <String>[..._bundledErrors];
    final raw = <String, List<SmokingArea>>{};
    var anyFresh = false;
    var usedCache = false;
    for (final source in _liveSources) {
      if (!source.covers(bounds)) continue;
      try {
        raw[source.id] = await source.fetch(bounds);
        anyFresh = true;
      } catch (e) {
        errors.add('${source.displayName}: $e');
        // Keep the last known data of this source instead of dropping it.
        final old = disk?.raw[source.id];
        if (old != null) {
          raw[source.id] = old;
          usedCache = true;
        }
      }
    }

    // Partial results (live source failed, nothing cached) are marked as
    // stale so that the next load retries the network.
    final fetchedAt =
        anyFresh ? DateTime.now() : (disk?.fetchedAt ?? DateTime(2000));
    final snapshot = _CacheSnapshot(fetchedAt: fetchedAt, raw: raw);
    _cities[city.id] = snapshot;
    _changed();
    if (anyFresh) await _writeCache(city, snapshot);

    final areas = areasIn(bounds);
    if (areas.isEmpty && !anyFresh && errors.isNotEmpty) {
      throw SourceException(errors.join('\n'));
    }
    return CityAreas(
      city: city,
      areas: areas,
      fetchedAt: fetchedAt,
      fromCache: usedCache,
      errors: errors,
    );
  }

  // ---------------------------------------------------------------------
  // Merging
  // ---------------------------------------------------------------------

  /// Combines the entries of all sources so that every real smoking area is
  /// shown only once:
  ///
  /// * identical ids are dropped,
  /// * every official entry is matched with at most one other entry (closest
  ///   pairs first). The merged entry keeps the official name, hours and
  ///   address, adds the OSM attributes and uses the OSM position when the
  ///   official one was only geocoded from an address,
  /// * other entries of different sources closer than
  ///   [duplicateThresholdMeters] are collapsed.
  static List<SmokingArea> merge(List<SmokingArea> input) {
    const distance = Distance();
    final byId = <String, SmokingArea>{};
    for (final a in input) {
      byId.putIfAbsent(a.id, () => a);
    }
    final official = <SmokingArea>[];
    final others = <SmokingArea>[];
    for (final a in byId.values) {
      (a.isOfficial ? official : others).add(a);
    }

    // Candidate pairs official <-> other, closest first.
    final othersGrid = _Grid<int>();
    for (var j = 0; j < others.length; j++) {
      othersGrid.add(others[j].position, j);
    }
    final pairs = <(double, int, int)>[];
    for (var i = 0; i < official.length; i++) {
      final o = official[i];
      final radius = o.isApproximate ? mergeRadiusGeocoded : mergeRadiusPrecise;
      for (final j in othersGrid.near(o.position)) {
        // Never merge a toilet with a smoking area.
        if (others[j].category != o.category) continue;
        final d = distance(o.position, others[j].position);
        if (d <= radius) pairs.add((d, i, j));
      }
    }
    pairs.sort((a, b) => a.$1.compareTo(b.$1));
    final usedO = <int>{};
    final usedX = <int>{};
    final merged = <int, SmokingArea>{};
    for (final (_, i, j) in pairs) {
      if (usedO.contains(i) || usedX.contains(j)) continue;
      usedO.add(i);
      usedX.add(j);
      merged[i] = _combine(official[i], others[j]);
    }

    final out = <SmokingArea>[];
    final outGrid = _Grid<SmokingArea>();
    void emit(SmokingArea a) {
      out.add(a);
      outGrid.add(a.position, a);
    }

    for (var i = 0; i < official.length; i++) {
      emit(merged[i] ?? official[i]);
    }
    for (var j = 0; j < others.length; j++) {
      if (usedX.contains(j)) continue;
      final a = others[j];
      final dup = outGrid.near(a.position).any((b) =>
          b.source != a.source &&
          b.category == a.category &&
          distance(a.position, b.position) < duplicateThresholdMeters);
      if (!dup) emit(a);
    }
    return out;
  }

  /// Kept for compatibility; see [merge].
  static List<SmokingArea> deduplicate(List<SmokingArea> input) =>
      merge(input);

  static SmokingArea _combine(SmokingArea official, SmokingArea other) {
    final tags = <String, String>{
      ...other.tags,
      ...official.tags,
      if (other.osmElement != null) 'osm:element': other.osmElement!,
    };
    // The OSM point is surveyed; prefer it over a geocoded address.
    final position =
        official.isApproximate ? other.position : official.position;
    if (official.isApproximate) tags.remove('geocoded');
    return SmokingArea(
      id: official.id,
      position: position,
      source: '${official.source} + ${other.source}',
      name: official.name ?? other.name,
      tags: tags,
    );
  }

  // ---------------------------------------------------------------------
  // Disk cache
  // ---------------------------------------------------------------------

  Future<File> _cacheFile(City city) async {
    final dir = await _cacheDirectory();
    final sub = Directory('${dir.path}/smoking_areas');
    if (!await sub.exists()) await sub.create(recursive: true);
    return File('${sub.path}/${city.id}.json');
  }

  Future<_CacheSnapshot?> _readCache(City city) async {
    try {
      final file = await _cacheFile(city);
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      var fetchedAt = DateTime.parse(json['fetchedAt'] as String);
      // Caches written before toilets existed lack them: show the data but
      // refresh at the next opportunity.
      if ((json['schema'] as int? ?? 1) < cacheSchema) fetchedAt = DateTime(2000);
      List<SmokingArea> parse(Object? list) => (list as List)
          .map((e) => SmokingArea.fromJson(e as Map<String, dynamic>))
          .toList();

      final raw = <String, List<SmokingArea>>{};
      final rawJson = json['raw'] as Map<String, dynamic>?;
      if (rawJson != null) {
        final bundledIds = {
          for (final s in sources)
            if (s.isBundled) s.id,
        };
        rawJson.forEach((k, v) {
          if (!bundledIds.contains(k)) raw[k] = parse(v);
        });
      } else if (json['areas'] != null) {
        // Cache of app version 1.0.x: OpenStreetMap data only.
        raw['osm'] = parse(json['areas'])
            .where((a) => a.id.startsWith('osm:'))
            .toList();
      }
      return _CacheSnapshot(fetchedAt: fetchedAt, raw: raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(City city, _CacheSnapshot data) async {
    try {
      final file = await _cacheFile(city);
      await file.writeAsString(jsonEncode({
        'schema': cacheSchema,
        'fetchedAt': data.fetchedAt.toIso8601String(),
        'raw': data.raw.map(
            (k, v) => MapEntry(k, v.map((a) => a.toJson()).toList())),
      }));
    } catch (_) {
      // Caching is best effort.
    }
  }
}

/// Per-source raw (unmerged) live data of one city.
class _CacheSnapshot {
  _CacheSnapshot({required this.fetchedAt, required this.raw});

  final DateTime fetchedAt;
  final Map<String, List<SmokingArea>> raw;
}

/// Simple spatial hash (cells of ~55 m) for neighbour look-ups.
class _Grid<T> {
  static const _cellLat = 0.0005;
  static const _cellLon = 0.0006;

  final Map<int, List<T>> _cells = {};

  int _key(int y, int x) => y * 1000003 + x;

  void add(LatLng p, T value) {
    final y = (p.latitude / _cellLat).floor();
    final x = (p.longitude / _cellLon).floor();
    (_cells[_key(y, x)] ??= []).add(value);
  }

  /// Values in the 3×3 cells around [p] (covers ≥ 50 m in every direction).
  Iterable<T> near(LatLng p) sync* {
    final y = (p.latitude / _cellLat).floor();
    final x = (p.longitude / _cellLon).floor();
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final cell = _cells[_key(y + dy, x + dx)];
        if (cell != null) yield* cell;
      }
    }
  }
}
