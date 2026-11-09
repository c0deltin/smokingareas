import 'dart:convert';
import 'dart:io';

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
  final List<SmokingArea> areas;
  final DateTime fetchedAt;
  final bool fromCache;

  /// Non fatal errors of individual sources.
  final List<String> errors;
}

/// Loads smoking areas from all registered sources and caches them per city
/// on disk, so the map and the proximity alerts also work offline.
class SmokingAreaRepository {
  SmokingAreaRepository({
    List<SmokingAreaSource>? sources,
    Future<Directory> Function()? cacheDirectory,
    this.maxAge = const Duration(days: 7),
  })  : sources = sources ?? [OfficialOpenDataSource(), OverpassSource()],
        _cacheDirectory = cacheDirectory ?? getApplicationSupportDirectory;

  final List<SmokingAreaSource> sources;
  final Future<Directory> Function() _cacheDirectory;
  final Duration maxAge;

  final Map<String, CityAreas> _memory = {};
  final Map<String, Future<CityAreas>> _inFlight = {};

  /// Distance below which two points of different sources are considered the
  /// same smoking area.
  static const double duplicateThresholdMeters = 8;

  List<String> get attributions =>
      sources.map((s) => s.attribution).toList(growable: false);

  CityAreas? cached(String cityId) => _memory[cityId];

  /// Every smoking area currently loaded in memory (all cities).
  Iterable<SmokingArea> get allLoaded sync* {
    final seen = <String>{};
    for (final c in _memory.values) {
      for (final a in c.areas) {
        if (seen.add(a.id)) yield a;
      }
    }
  }

  /// Loads [city]. Uses the disk cache if it is younger than [maxAge] unless
  /// [forceRefresh] is set. Falls back to stale cache if the network fails.
  Future<CityAreas> load(City city, {bool forceRefresh = false}) {
    if (!forceRefresh) {
      final mem = _memory[city.id];
      if (mem != null && !_isStale(mem.fetchedAt)) return Future.value(mem);
    }
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
    final result = <SmokingArea>[];
    for (final c in cities) {
      try {
        result.addAll((await load(c)).areas);
      } catch (_) {
        // Ignore – proximity checks just use what is available.
      }
    }
    return result;
  }

  bool _isStale(DateTime fetchedAt) =>
      DateTime.now().difference(fetchedAt) > maxAge;

  Future<CityAreas> _load(City city, bool forceRefresh) async {
    final version = await _dataVersion();
    final disk = await _readCache(city);
    if (!forceRefresh &&
        disk != null &&
        disk.version == version &&
        !_isStale(disk.fetchedAt)) {
      final cached = disk.toCityAreas(city);
      _memory[city.id] = cached;
      return cached;
    }

    final bounds = city.bounds;
    final errors = <String>[];
    final raw = <String, List<SmokingArea>>{};
    var anyFresh = false;
    var usedCache = false;
    for (final source in sources) {
      if (!source.covers(bounds)) continue;
      try {
        raw[source.id] = await source.fetch(bounds);
        if (source is! OfficialOpenDataSource) anyFresh = true;
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

    if (raw.values.every((l) => l.isEmpty) && errors.isNotEmpty) {
      throw SourceException(errors.join('\n'));
    }

    // Partial results (live source failed, nothing cached) are marked as
    // stale so the next load retries the network.
    final fetchedAt =
        anyFresh ? DateTime.now() : (disk?.fetchedAt ?? DateTime(2000));
    final snapshot = _CacheSnapshot(
      version: version,
      fetchedAt: fetchedAt,
      raw: raw,
    );
    final result = CityAreas(
      city: city,
      areas: merge(raw.values.expand((l) => l).toList()),
      fetchedAt: fetchedAt,
      fromCache: usedCache,
      errors: errors,
    );
    _memory[city.id] = result;
    // Only persist when something new was fetched, so a failed refresh does
    // not reset the age of the cached OSM data.
    if (anyFresh || (disk != null && disk.version != version)) {
      await _writeCache(city, snapshot);
    }
    return result;
  }

  Future<String> _dataVersion() async {
    final parts = <String>[];
    for (final s in sources) {
      if (s is OfficialOpenDataSource) {
        try {
          parts.add('${s.id}@${await s.version()}');
        } catch (_) {}
      }
    }
    return parts.join(',');
  }

  /// Maximum distance at which an official entry and an OSM entry are treated
  /// as the same smoking area. Official coordinates from a CSV are precise;
  /// geocoded street addresses can be a few dozen metres off.
  static const double mergeRadiusPrecise = 25;
  static const double mergeRadiusGeocoded = 50;

  /// Combines the entries of all sources so that every real smoking area is
  /// shown only once:
  ///
  /// * identical ids are dropped,
  /// * every official entry is matched with at most one OSM entry (closest
  ///   pairs first). The merged entry keeps the official name, hours and
  ///   address, adds the OSM attributes and uses the OSM position when the
  ///   official one was only geocoded from an address.
  /// * other entries of different sources closer than
  ///   [duplicateThresholdMeters] are collapsed.
  static List<SmokingArea> merge(List<SmokingArea> input) {
    const distance = Distance();
    final byId = <String, SmokingArea>{};
    for (final a in input) {
      byId.putIfAbsent(a.id, () => a);
    }
    final official = byId.values.where((a) => a.isOfficial).toList();
    final others = byId.values.where((a) => !a.isOfficial).toList();

    // Candidate pairs official <-> other, closest first.
    final pairs = <(double, int, int)>[];
    for (var i = 0; i < official.length; i++) {
      final o = official[i];
      final radius = o.isApproximate ? mergeRadiusGeocoded : mergeRadiusPrecise;
      for (var j = 0; j < others.length; j++) {
        final x = others[j];
        if ((x.latitude - o.latitude).abs() > 0.001 ||
            (x.longitude - o.longitude).abs() > 0.0012) {
          continue;
        }
        final d = distance(o.position, x.position);
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

    final out = <SmokingArea>[
      for (var i = 0; i < official.length; i++) merged[i] ?? official[i],
    ];
    for (var j = 0; j < others.length; j++) {
      if (usedX.contains(j)) continue;
      final a = others[j];
      final dup = out.any((b) =>
          b.source != a.source &&
          distance(a.position, b.position) < duplicateThresholdMeters);
      if (!dup) out.add(a);
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
    final position = official.isApproximate ? other.position : official.position;
    if (official.isApproximate) tags.remove('geocoded');
    return SmokingArea(
      id: official.id,
      position: position,
      source: '${official.source} + ${other.source}',
      name: official.name ?? other.name,
      tags: tags,
    );
  }

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
      final raw = <String, List<SmokingArea>>{};
      final rawJson = json['raw'] as Map<String, dynamic>?;
      if (rawJson == null) return null; // old cache format
      rawJson.forEach((k, v) {
        raw[k] = (v as List)
            .map((e) => SmokingArea.fromJson(e as Map<String, dynamic>))
            .toList();
      });
      return _CacheSnapshot(
        version: json['version'] as String? ?? '',
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        raw: raw,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(City city, _CacheSnapshot data) async {
    try {
      final file = await _cacheFile(city);
      await file.writeAsString(jsonEncode({
        'version': data.version,
        'fetchedAt': data.fetchedAt.toIso8601String(),
        'raw': data.raw.map(
            (k, v) => MapEntry(k, v.map((a) => a.toJson()).toList())),
      }));
    } catch (_) {
      // Caching is best effort.
    }
  }
}

/// Per-source raw data of one city as stored on disk.
class _CacheSnapshot {
  _CacheSnapshot({
    required this.version,
    required this.fetchedAt,
    required this.raw,
  });

  final String version;
  final DateTime fetchedAt;
  final Map<String, List<SmokingArea>> raw;

  CityAreas toCityAreas(City city) => CityAreas(
        city: city,
        areas: SmokingAreaRepository.merge(
            raw.values.expand((l) => l).toList()),
        fetchedAt: fetchedAt,
        fromCache: true,
      );
}
