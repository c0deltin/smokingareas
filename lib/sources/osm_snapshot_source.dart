import 'dart:convert';

import '../models/city.dart';
import '../models/smoking_area.dart';
import '../services/snapshot_updater.dart';
import 'overpass_source.dart';
import 'smoking_area_source.dart';

/// OpenStreetMap smoking areas and public toilets of all covered cities,
/// exported weekly by CI (`tool/opendata/update_osm.py`), bundled with every
/// app build and updated by the [SnapshotUpdater] – so installed apps do not
/// query the public Overpass servers themselves. [OverpassSource] only
/// serves as live fallback when no export is available at all.
class OsmSnapshotSource extends SmokingAreaSource implements SnapshotDataset {
  OsmSnapshotSource(this._read);

  /// Reads the downloaded snapshot (null when there is none yet).
  final Future<String?> Function() _read;
  Future<_OsmSnapshot>? _snapshot;

  /// True once a snapshot is loaded and not empty (disables live queries).
  bool get hasData => _hasData;
  bool _hasData = false;

  @override
  String get id => 'osm';

  @override
  String get displayName => 'OpenStreetMap';

  @override
  String get attribution => '© OpenStreetMap contributors (ODbL)';

  @override
  bool get isBundled => true;

  Future<_OsmSnapshot> _load() => _snapshot ??= () async {
        final json = await _read();
        final snap = json == null ? _OsmSnapshot.empty : _OsmSnapshot.parse(json);
        _hasData = snap.areas.isNotEmpty;
        return snap;
      }();

  @override
  Future<List<SmokingArea>> fetch(GeoBounds bounds) async =>
      (await _load()).areas;

  // --- SnapshotDataset ---------------------------------------------------

  @override
  String get manifestName => 'osm-manifest.json';

  @override
  String get dataName => 'osm_spots.json.gz';

  @override
  Future<String> version() async => (await _load()).generated;

  @override
  Future<int> entryCount() async => (await _load()).areas.length;

  @override
  List<dynamic>? entriesOf(Map<String, dynamic> snapshot) =>
      snapshot['elements'] as List?;

  @override
  void validate(String json) {
    if (_OsmSnapshot.parse(json).areas.isEmpty) {
      throw const FormatException('empty OSM snapshot');
    }
  }

  @override
  void invalidate() => _snapshot = null;
}

class _OsmSnapshot {
  const _OsmSnapshot(this.generated, this.areas);

  static const empty = _OsmSnapshot('', []);

  final String generated;
  final List<SmokingArea> areas;

  /// Same element format as an Overpass response.
  static _OsmSnapshot parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return _OsmSnapshot(
        data['generated'] as String? ?? '', OverpassSource.parse(json));
  }
}
