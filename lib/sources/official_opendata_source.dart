import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../models/city.dart';
import '../models/data_fingerprint.dart';
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
  String get label => officialDatasetLabel(id, name);
}

const _tokyoWards = {
  'chiyoda': 'Chiyoda', 'chuo': 'Chūō', 'shinjuku': 'Shinjuku',
  'taito': 'Taitō', 'sumida': 'Sumida', 'koto': 'Kōtō',
  'meguro': 'Meguro', 'suginami': 'Suginami', 'toshima': 'Toshima',
  'arakawa': 'Arakawa', 'itabashi': 'Itabashi', 'nerima': 'Nerima',
  'katsushika': 'Katsushika', 'edogawa': 'Edogawa', 'shibuya': 'Shibuya',
};

/// German label of an official dataset id (e.g. `tokyo_sumida_toilets`).
String officialDatasetLabel(String id, String fallback) {
  final fixed = kOfficialDatasetLabels[id];
  if (fixed != null) return fixed;
  final m = RegExp(r'^tokyo_([a-z]+)_toilets$').firstMatch(id);
  if (m != null && _tokyoWards[m.group(1)] != null) {
    return 'Tokyo, ${_tokyoWards[m.group(1)]} ward (open data)';
  }
  return fallback;
}

const kOfficialDatasetLabels = {
  'kyoto_toilets': 'City of Kyoto (open data)',
  'okayama_toilets': 'City of Okayama (open data)',
  'kyoto': 'City of Kyoto (open data)',
  'osaka': 'City of Osaka (smoking area list)',
  'tokyo_koto': 'Tokyo, Kōtō ward (open data)',
  'tokyo_taito': 'Tokyo, Taitō ward (open data)',
  'tokyo_chiyoda': 'Tokyo, Chiyoda ward (smoking area list)',
  'tokyo_shinjuku': 'Tokyo, Shinjuku ward (smoking area list)',
  'tokyo_shibuya': 'Tokyo, Shibuya ward (smoking area list)',
  'tokyo_toshima': 'Tokyo, Toshima ward (smoking area list)',
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
  String get displayName => 'Official city data';

  @override
  bool get isBundled => true;

  @override
  String get attribution =>
      'Smoking areas: City of Kyoto, City of Osaka, Tokyo wards Chiyoda, '
      'Kōtō, Shibuya, Shinjuku, Taitō, Toshima. Public toilets: City of '
      'Kyoto, City of Okayama and 14 Tokyo wards (公衆トイレ一覧). Open data '
      'CC BY 4.0 or information published on the official websites; address '
      'geocoding: GSI Japan';

  Future<_Snapshot> _load() => _snapshot ??= _loader().then(_Snapshot.parse);

  Future<List<OfficialDataset>> datasets() async => (await _load()).datasets;

  /// Date the snapshot was generated.
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
        if (a['category'] == 'toilet') 'amenity': 'toilets',
        // Former ids of this entry (see importer `carry_aliases`).
        if (a['aliases'] is List && (a['aliases'] as List).isNotEmpty)
          'aliases': (a['aliases'] as List).join(','),
        if (a['temporarily_closed'] == true) 'temporarily_closed': 'yes',
        // Marks the closure as coming from the data (not the community).
        if (a['temporarily_closed'] == true) 'official:closed': 'yes',
        if (a['temporarily_closed'] == true && a['note'] != null)
          'temporarily_closed:note': a['note'] as String,
        if (a['wheelchair'] != null)
          'wheelchair': a['wheelchair'] == true ? 'yes' : 'no',
        if (a['changing_table'] != null)
          'changing_table': a['changing_table'] == true ? 'yes' : 'no',
      };
      // Content of the official entry: a change restarts community verdicts.
      final position = LatLng(
        (a['lat'] as num).toDouble(),
        (a['lon'] as num).toDouble(),
      );
      tags[fingerprintTag] = dataFingerprint(position: position, fields: {
        'name': '${a['name'] ?? ''}',
        'address': '${a['address'] ?? ''}',
        'hours': '${a['hours'] ?? ''}',
        'kind': '${a['kind'] ?? ''}',
        'category': '${a['category'] ?? 'smoking'}',
        'closed': '${a['temporarily_closed'] == true}',
      });
      areas.add(SmokingArea(
        id: a['id'] as String,
        position: LatLng(
          (a['lat'] as num).toDouble(),
          (a['lon'] as num).toDouble(),
        ),
        source: ds?.label ??
            officialDatasetLabel(a['source'] as String, a['source'] as String),
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
