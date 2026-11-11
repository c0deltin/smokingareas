import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A data set that is published as `<data>.json.gz` plus a small manifest
/// (release `opendata`) and updated on the device without an app release.
abstract class SnapshotDataset {
  /// File names in the release.
  String get manifestName;
  String get dataName;

  /// Version of the data in use ('' when there is none).
  Future<String> version();

  /// Number of entries in use (to refuse suspiciously small downloads).
  Future<int> entryCount();

  /// The entries of a downloaded snapshot (null when missing).
  List<dynamic>? entriesOf(Map<String, dynamic> snapshot);

  /// Throws when [json] cannot be used.
  void validate(String json);

  /// Drops loaded data so the next read uses the new snapshot.
  void invalidate();
}

/// Something that can check for newer data (one or several data sets).
abstract class DataUpdater {
  Future<SnapshotUpdateResult> check({bool force = false});
}

/// Where over-the-air snapshots are published: assets of the GitHub release
/// with tag `opendata` (see `.github/workflows/opendata.yml`).
final Uri kOpenDataBaseUri = Uri.parse(
    'https://github.com/c0deltin/smokingareas/releases/download/opendata/');

/// Highest snapshot `format` this app version understands.
const int supportedSnapshotFormat = 1;

/// Version string of a snapshot (`generated`, ISO 8601 – compares as text).
String? snapshotVersion(String json) =>
    RegExp(r'"generated"\s*:\s*"([^"]+)"').firstMatch(json)?.group(1);

/// A downloaded snapshot on the device.
class SnapshotStore {
  SnapshotStore(this._directory,
      {this.fileName = 'official_snapshot.json', this.metaName = 'meta.json'});

  final Future<Directory> Function() _directory;
  final String fileName;
  final String metaName;

  Future<Directory> _dir() async {
    final d = Directory('${(await _directory()).path}/opendata');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> get _snapshot async => File('${(await _dir()).path}/$fileName');
  Future<File> get _meta async => File('${(await _dir()).path}/$metaName');

  /// The downloaded snapshot (JSON text), or null.
  Future<String?> read() async {
    try {
      final f = await _snapshot;
      return await f.exists() ? await f.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String json) async {
    final f = await _snapshot;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json);
    await tmp.rename(f.path);
  }

  Future<DateTime?> lastCheck() async {
    try {
      final f = await _meta;
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return DateTime.tryParse(j['lastCheck'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastCheck(DateTime t) async {
    try {
      await (await _meta)
          .writeAsString(jsonEncode({'lastCheck': t.toIso8601String()}));
    } catch (_) {}
  }

  /// Loader for [OfficialOpenDataSource]: the downloaded snapshot if it is
  /// newer than the bundled one, otherwise the bundled one.
  Future<String> Function() preferNewer(Future<String> Function() bundled) =>
      () async {
        final b = await bundled();
        final d = await read();
        if (d == null) return b;
        final dv = snapshotVersion(d);
        final bv = snapshotVersion(b);
        if (dv == null || (bv != null && dv.compareTo(bv) <= 0)) return b;
        return d;
      };
}

enum SnapshotUpdateStatus { updated, upToDate, skipped, failed }

class SnapshotUpdateResult {
  const SnapshotUpdateResult(this.status, {this.version, this.error});
  final SnapshotUpdateStatus status;
  final String? version;
  final String? error;

  bool get updated => status == SnapshotUpdateStatus.updated;
}

/// Updates a data set without an app release: polls a tiny manifest and
/// downloads the (gzip) snapshot only when it is newer than the data in use.
/// Every download is validated before it replaces anything.
class SnapshotUpdater implements DataUpdater {
  SnapshotUpdater({
    required this.store,
    required this.source,
    http.Client? client,
    Uri? baseUri,
    this.minInterval = const Duration(hours: 24),
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _base = baseUri ?? kOpenDataBaseUri,
        _now = clock ?? DateTime.now;

  final SnapshotStore store;
  final SnapshotDataset source;
  final http.Client _client;
  final Uri _base;
  final Duration minInterval;
  final DateTime Function() _now;

  /// Checks for newer data. Without [force] at most once per [minInterval].
  @override
  Future<SnapshotUpdateResult> check({bool force = false}) async {
    final now = _now();
    if (!force) {
      final last = await store.lastCheck();
      if (last != null && now.difference(last) < minInterval) {
        return const SnapshotUpdateResult(SnapshotUpdateStatus.skipped);
      }
    }
    try {
      final result = await _check();
      await store.setLastCheck(now);
      return result;
    } catch (e) {
      return SnapshotUpdateResult(SnapshotUpdateStatus.failed, error: '$e');
    }
  }

  Future<SnapshotUpdateResult> _check() async {
    final manifestRes = await _client
        .get(_base.resolve(source.manifestName))
        .timeout(const Duration(seconds: 20));
    if (manifestRes.statusCode != 200) {
      throw HttpException('manifest: HTTP ${manifestRes.statusCode}');
    }
    final manifest =
        jsonDecode(utf8.decode(manifestRes.bodyBytes)) as Map<String, dynamic>;
    final format = (manifest['format'] as num?)?.toInt() ?? 1;
    final version = manifest['generated'] as String?;
    final count = (manifest['count'] as num?)?.toInt();
    if (format > supportedSnapshotFormat) {
      // Needs a newer app – keep the current data.
      return SnapshotUpdateResult(SnapshotUpdateStatus.upToDate,
          version: await source.version());
    }
    final current = await source.version();
    if (version == null || version.compareTo(current) <= 0) {
      return SnapshotUpdateResult(SnapshotUpdateStatus.upToDate,
          version: current);
    }

    final res = await _client
        .get(_base.resolve(source.dataName))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw HttpException('snapshot: HTTP ${res.statusCode}');
    }
    final json = utf8.decode(gzip.decode(res.bodyBytes));

    // Validate before replacing anything.
    final data = jsonDecode(json) as Map<String, dynamic>;
    if (((data['format'] as num?)?.toInt() ?? 1) > supportedSnapshotFormat) {
      throw const FormatException('unsupported snapshot format');
    }
    if (data['generated'] != version) {
      throw const FormatException('snapshot does not match the manifest');
    }
    final areas = source.entriesOf(data);
    if (areas == null || (count != null && areas.length != count)) {
      throw const FormatException('incomplete snapshot');
    }
    final currentCount = await source.entryCount();
    if (areas.length < currentCount * 0.5) {
      throw FormatException(
          'suspiciously small snapshot (${areas.length} vs $currentCount)');
    }
    source.validate(json); // throws if unreadable

    await store.write(json);
    source.invalidate();
    return SnapshotUpdateResult(SnapshotUpdateStatus.updated,
        version: version);
  }
}

/// Checks several data sets; "updated" when any of them was updated.
class DataUpdaters implements DataUpdater {
  DataUpdaters(this.updaters);
  final List<DataUpdater> updaters;

  @override
  Future<SnapshotUpdateResult> check({bool force = false}) async {
    final results = await Future.wait(
        [for (final u in updaters) u.check(force: force)]);
    for (final r in results) {
      if (r.updated) return r;
    }
    return results.first;
  }
}
