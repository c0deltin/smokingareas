import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/city.dart';
import '../models/smoking_area.dart';
import '../sources/overpass_source.dart';
import 'snapshot_updater.dart';

/// Highest tiles format this app understands (see `update_osm.py`).
const int supportedTilesFormat = 2;

/// What is installed: version and number of elements per tile.
class TileIndex {
  const TileIndex({
    required this.generated,
    required this.count,
    required this.tiles,
  });

  final String generated;
  final int count;

  /// Tile id (`<lat>_<lon>`) -> number of elements.
  final Map<String, int> tiles;

  Map<String, dynamic> toJson() =>
      {'generated': generated, 'count': count, 'tiles': tiles};

  factory TileIndex.fromJson(Map<String, dynamic> j) => TileIndex(
        generated: j['generated'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        tiles: {
          for (final e in ((j['tiles'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
      );
}

/// The OpenStreetMap data of all of Japan on the device, split into tiles of
/// 1° × 1° (one file per tile). The weekly export (`osm_tiles.txt.gz`) is
/// installed line by line – it is never parsed as a whole – and the app only
/// parses the tiles around the map and the user ([load]).
class OsmTileStore {
  OsmTileStore(this._directory);

  final Future<Directory> Function() _directory;
  TileIndex? _index;
  bool _indexRead = false;

  static final _tileId = RegExp(r'^-?\d{1,3}_-?\d{1,3}$');

  /// Tile id (`<lat>_<lon>`) of the cell containing [p].
  static String tileOf(LatLng p) =>
      '${p.latitude.floor()}_${p.longitude.floor()}';

  /// Ids of all tiles that overlap [b].
  static List<String> tilesIn(GeoBounds b) => [
        for (var lat = b.south.floor(); lat <= b.north.floor(); lat++)
          for (var lon = b.west.floor(); lon <= b.east.floor(); lon++)
            '${lat}_$lon',
      ];

  Future<Directory> _root() async {
    final d = Directory('${(await _directory()).path}/opendata/osm_tiles');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory> _current() async =>
      Directory('${(await _root()).path}/current');

  /// The installed data, or null when there is none.
  Future<TileIndex?> index() async {
    if (_indexRead) return _index;
    try {
      final f = File('${(await _current()).path}/index.json');
      if (await f.exists()) {
        _index = TileIndex.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {
      _index = null;
    }
    _indexRead = true;
    return _index;
  }

  /// Version of the installed data ('' when there is none).
  Future<String> version() async => (await index())?.generated ?? '';

  /// Version (`generated`) in the header of a tiles file, read from its
  /// first line only.
  static Future<String?> versionOf(Stream<List<int>> gz) async {
    try {
      final first = await gz
          .transform(gzip.decoder)
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
      return (jsonDecode(first) as Map<String, dynamic>)['generated']
          as String?;
    } catch (_) {
      return null;
    }
  }

  /// Installs a tiles file (gzip). Everything is checked before the
  /// installed data is replaced: the format, the version and number of
  /// elements announced by the header (and by the manifest when given).
  Future<TileIndex> install(
    Stream<List<int>> gz, {
    String? expectedVersion,
    int? expectedCount,
  }) async {
    final root = await _root();
    final tmp = Directory(
        '${root.path}/tmp-${DateTime.now().microsecondsSinceEpoch}');
    await tmp.create(recursive: true);
    try {
      Map<String, dynamic>? header;
      final tiles = <String, int>{};
      final lines = gz
          .transform(gzip.decoder)
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (header == null) {
          header = jsonDecode(line) as Map<String, dynamic>;
          final format = (header['format'] as num?)?.toInt() ?? 0;
          if (format < 2 || format > supportedTilesFormat) {
            throw FormatException('unsupported tiles format $format');
          }
          continue;
        }
        if (line.trim().isEmpty) continue;
        final tab = line.indexOf('\t');
        final id = tab < 0 ? '' : line.substring(0, tab);
        if (!_tileId.hasMatch(id)) {
          throw const FormatException('bad tile line');
        }
        final data = line.substring(tab + 1);
        // Counted without parsing: every element has exactly one "type".
        tiles[id] = '"type":'.allMatches(data).length;
        await File('${tmp.path}/$id.json').writeAsString(data);
      }
      if (header == null) throw const FormatException('empty tiles file');
      final generated = header['generated'] as String? ?? '';
      final count = tiles.values.fold(0, (a, b) => a + b);
      if (generated.isEmpty ||
          (expectedVersion != null && generated != expectedVersion)) {
        throw const FormatException('tiles do not match the manifest');
      }
      if (count != (header['count'] as num?)?.toInt() ||
          (expectedCount != null && count != expectedCount)) {
        throw const FormatException('incomplete tiles file');
      }
      final index = TileIndex(generated: generated, count: count, tiles: tiles);
      await File('${tmp.path}/index.json')
          .writeAsString(jsonEncode(index.toJson()));

      // Switch over: the new directory becomes "current".
      final current = await _current();
      final old = Directory('${root.path}/old');
      if (await old.exists()) await old.delete(recursive: true);
      if (await current.exists()) await current.rename(old.path);
      await tmp.rename(current.path);
      if (await old.exists()) await old.delete(recursive: true);
      _index = index;
      _indexRead = true;
      return index;
    } catch (e) {
      if (await tmp.exists()) await tmp.delete(recursive: true);
      rethrow;
    }
  }

  /// The spots of one tile ([] when the tile has no data).
  Future<List<SmokingArea>> load(String tile) async {
    final idx = await index();
    if (idx == null || !idx.tiles.containsKey(tile)) return const [];
    try {
      final data =
          await File('${(await _current()).path}/$tile.json').readAsString();
      // Large tiles (city centres) are parsed off the UI thread.
      return data.length > 100000
          ? await compute(_parseTile, data)
          : _parseTile(data);
    } catch (_) {
      return const [];
    }
  }

  static List<SmokingArea> _parseTile(String data) =>
      OverpassSource.parse('{"elements":$data}');
}

/// Installs the tiles file bundled with the app when it is newer than the
/// data on the device (first start, or an app update with newer data).
/// Returns whether it was installed.
Future<bool> installBundledTiles(
  OsmTileStore store,
  Future<List<int>?> Function() bundled,
) async {
  try {
    final bytes = await bundled();
    if (bytes == null || bytes.isEmpty) return false;
    final bundledVersion =
        await OsmTileStore.versionOf(Stream.value(bytes)) ?? '';
    if (bundledVersion.compareTo(await store.version()) <= 0) return false;
    await store.install(Stream.value(bytes));
    return true;
  } catch (_) {
    // Keep what is installed; the updater tries again later.
    return false;
  }
}

/// Updates the tiles without an app release: polls the small manifest of
/// the data release and downloads the tiles file only when it is newer.
class OsmTileUpdater implements DataUpdater {
  OsmTileUpdater({
    required this.store,
    this.onUpdated,
    http.Client? client,
    Uri? baseUri,
    this.minInterval = const Duration(hours: 24),
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _base = baseUri ?? kOpenDataBaseUri,
        _now = clock ?? DateTime.now;

  static const manifestName = 'osm-tiles-manifest.json';
  static const dataName = 'osm_tiles.txt.gz';

  final OsmTileStore store;

  /// Called after new tiles were installed (e.g. to reload loaded tiles).
  final Future<void> Function()? onUpdated;
  final http.Client _client;
  final Uri _base;
  final Duration minInterval;
  final DateTime Function() _now;
  DateTime? _lastCheck;

  @override
  Future<SnapshotUpdateResult> check({bool force = false}) async {
    final now = _now();
    final last = _lastCheck;
    if (!force && last != null && now.difference(last) < minInterval) {
      return const SnapshotUpdateResult(SnapshotUpdateStatus.skipped);
    }
    try {
      final result = await _check();
      _lastCheck = now;
      return result;
    } catch (e) {
      return SnapshotUpdateResult(SnapshotUpdateStatus.failed, error: '$e');
    }
  }

  Future<SnapshotUpdateResult> _check() async {
    final res = await _client
        .get(_base.resolve(manifestName))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw HttpException('tiles manifest: HTTP ${res.statusCode}');
    }
    final manifest =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final format = (manifest['format'] as num?)?.toInt() ?? 0;
    final version = manifest['generated'] as String?;
    final count = (manifest['count'] as num?)?.toInt();
    final current = await store.version();
    if (format > supportedTilesFormat ||
        version == null ||
        version.compareTo(current) <= 0) {
      return SnapshotUpdateResult(SnapshotUpdateStatus.upToDate,
          version: current);
    }
    final installed = (await store.index())?.count ?? 0;
    if (count == null || count < installed * 0.5) {
      throw FormatException('suspiciously small tiles ($count vs $installed)');
    }
    final data = await _client
        .get(_base.resolve(dataName))
        .timeout(const Duration(minutes: 3));
    if (data.statusCode != 200) {
      throw HttpException('tiles: HTTP ${data.statusCode}');
    }
    await store.install(Stream.value(data.bodyBytes),
        expectedVersion: version, expectedCount: count);
    await onUpdated?.call();
    return SnapshotUpdateResult(SnapshotUpdateStatus.updated, version: version);
  }
}
