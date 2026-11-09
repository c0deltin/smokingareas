import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../data/cities.dart';
import '../models/city.dart';
import '../models/smoking_area.dart';
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
  })  : sources = sources ?? [OverpassSource()],
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
    return _inFlight[city.id] ??= _load(city, forceRefresh)
        .whenComplete(() => _inFlight.remove(city.id));
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
    final disk = await _readCache(city);
    if (!forceRefresh && disk != null && !_isStale(disk.fetchedAt)) {
      _memory[city.id] = disk;
      return disk;
    }

    final bounds = city.bounds;
    final errors = <String>[];
    final collected = <SmokingArea>[];
    var anySuccess = false;
    for (final source in sources) {
      if (!source.covers(bounds)) continue;
      try {
        collected.addAll(await source.fetch(bounds));
        anySuccess = true;
      } catch (e) {
        errors.add('${source.displayName}: $e');
      }
    }

    if (!anySuccess) {
      if (disk != null) {
        final stale = CityAreas(
          city: city,
          areas: disk.areas,
          fetchedAt: disk.fetchedAt,
          fromCache: true,
          errors: errors,
        );
        _memory[city.id] = stale;
        return stale;
      }
      throw SourceException(errors.join('\n'));
    }

    final result = CityAreas(
      city: city,
      areas: deduplicate(collected),
      fetchedAt: DateTime.now(),
      errors: errors,
    );
    _memory[city.id] = result;
    await _writeCache(result);
    return result;
  }

  /// Removes entries with the same id and entries of different sources that
  /// are closer than [duplicateThresholdMeters] to each other.
  static List<SmokingArea> deduplicate(List<SmokingArea> input) {
    const distance = Distance();
    final byId = <String, SmokingArea>{};
    for (final a in input) {
      byId.putIfAbsent(a.id, () => a);
    }
    final out = <SmokingArea>[];
    for (final a in byId.values) {
      final dup = out.any((b) =>
          b.source != a.source &&
          distance(a.position, b.position) < duplicateThresholdMeters);
      if (!dup) out.add(a);
    }
    return out;
  }

  Future<File> _cacheFile(City city) async {
    final dir = await _cacheDirectory();
    final sub = Directory('${dir.path}/smoking_areas');
    if (!await sub.exists()) await sub.create(recursive: true);
    return File('${sub.path}/${city.id}.json');
  }

  Future<CityAreas?> _readCache(City city) async {
    try {
      final file = await _cacheFile(city);
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final areas = (json['areas'] as List)
          .map((e) => SmokingArea.fromJson(e as Map<String, dynamic>))
          .toList();
      return CityAreas(
        city: city,
        areas: areas,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(CityAreas data) async {
    try {
      final file = await _cacheFile(data.city);
      await file.writeAsString(jsonEncode({
        'fetchedAt': data.fetchedAt.toIso8601String(),
        'areas': data.areas.map((a) => a.toJson()).toList(),
      }));
    } catch (_) {
      // Caching is best effort.
    }
  }
}
