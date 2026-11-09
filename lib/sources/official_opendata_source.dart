import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../models/city.dart';
import '../models/smoking_area.dart';
import 'smoking_area_source.dart';

/// Metadata of one official (municipal) dataset inside the snapshot.
class OfficialDataset {
  const OfficialDataset({
    required this.id,
    required this.name,
    required this.url,
    required this.license,
    this.fetched,
  });

  final String id;
  final String name;
  final String url;
  final String license;
  final String? fetched;

  /// Short German label used in the UI.
  String get label => kOfficialDatasetLabels[id] ?? name;
}

const kOfficialDatasetLabels = {
  'kyoto': 'Stadt Kyoto (Open Data)',
  'osaka': 'Stadt Osaka (Liste der Raucherplätze)',
  'tokyo_koto': 'Tokio, Bezirk Kōtō (Open Data)',
  'tokyo_taito': 'Tokio, Bezirk Taitō (Open Data)',
  'tokyo_chiyoda': 'Tokio, Bezirk Chiyoda (Liste der Raucherplätze)',
  'tokyo_shinjuku': 'Tokio, Bezirk Shinjuku (Liste der Raucherplätze)',
  'tokyo_shibuya': 'Tokio, Bezirk Shibuya (Liste der Raucherplätze)',
  'tokyo_toshima': 'Tokio, Bezirk Toshima (Liste der Raucherplätze)',
};

/// Official smoking areas published by Japanese cities / Tokyo wards.
///
/// The lists come in many formats (CSV, HTML pages, form downloads), so they
/// are normalised at build time by `tool/opendata/update_opendata.py` into a
/// JSON snapshot that is bundled with the app. This source serves that
/// snapshot; the repository merges it with live OpenStreetMap data.
class OfficialOpenDataSource extends SmokingAreaSource {
  OfficialOpenDataSource({Future<String> Function()? loader})
      : _loader = loader ??
            (() => rootBundle
                .loadString('assets/opendata/official_smoking_areas.json'));

  final Future<String> Function() _loader;
  Future<_Snapshot>? _snapshot;

  @override
  String get id => 'official';

  @override
  String get displayName => 'Offizielle Daten der Städte';

  @override
  String get attribution =>
      'Stadt Kyoto, Stadt Osaka, Tokioter Bezirke Chiyoda, Kōtō, Shibuya, '
      'Shinjuku, Taitō, Toshima (Open Data CC BY 4.0 bzw. Angaben der '
      'offiziellen Webseiten); Adress-Geocoding: GSI Japan';

  Future<_Snapshot> _load() => _snapshot ??= _loader().then(_Snapshot.parse);

  Future<List<OfficialDataset>> datasets() async => (await _load()).datasets;

  /// Snapshot date – used to invalidate cached city data on app updates.
  Future<String> version() async => (await _load()).generated;

  @override
  Future<List<SmokingArea>> fetch(GeoBounds bounds) async {
    final snap = await _load();
    return snap.areas.where((a) => bounds.contains(a.position)).toList();
  }
}

class _Snapshot {
  _Snapshot(this.generated, this.datasets, this.areas);

  final String generated;
  final List<OfficialDataset> datasets;
  final List<SmokingArea> areas;

  static _Snapshot parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final datasets = <String, OfficialDataset>{};
    for (final raw in (json['sources'] as List? ?? const [])) {
      final s = raw as Map<String, dynamic>;
      final d = OfficialDataset(
        id: s['id'] as String,
        name: s['name'] as String,
        url: s['url'] as String,
        license: s['license'] as String? ?? '',
        fetched: s['fetched'] as String?,
      );
      datasets[d.id] = d;
    }
    final areas = <SmokingArea>[];
    for (final raw in (json['areas'] as List? ?? const [])) {
      final a = raw as Map<String, dynamic>;
      final ds = datasets[a['source']];
      final tags = <String, String>{
        'official': 'yes',
        'official:dataset': a['source'] as String,
        if (ds != null) 'official:url': ds.url,
        if (a['address'] != null) 'addr:full': a['address'] as String,
        if (a['hours'] != null) 'opening_hours': a['hours'] as String,
        if (a['kind'] != null) 'official:kind': a['kind'] as String,
        if (a['note'] != null) 'note': a['note'] as String,
        if (a['geocoded'] == true) 'geocoded': 'yes',
        if (a['members'] != null) 'official:rooms': '${a['members']}',
      };
      areas.add(SmokingArea(
        id: a['id'] as String,
        position: LatLng(
          (a['lat'] as num).toDouble(),
          (a['lon'] as num).toDouble(),
        ),
        source: ds?.label ?? a['source'] as String,
        name: a['name'] as String?,
        tags: tags,
      ));
    }
    return _Snapshot(
      json['generated'] as String? ?? '',
      datasets.values.toList(),
      areas,
    );
  }
}
