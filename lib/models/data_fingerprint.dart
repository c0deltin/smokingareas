import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// Tag holding the fingerprint of an entry's *source data* (official snapshot
/// or OSM). Community verdicts remember the fingerprint they were made for;
/// when the source entry changes, older verdicts stop counting.
const fingerprintTag = 'data:fingerprint';

/// FNV-1a (32 bit) of a canonical description of the entry's content.
String dataFingerprint({
  required LatLng position,
  required Map<String, String> fields,
}) {
  final keys = fields.keys.toList()..sort();
  final canonical = StringBuffer()
    ..write(position.latitude.toStringAsFixed(5))
    ..write(',')
    ..write(position.longitude.toStringAsFixed(5));
  for (final k in keys) {
    canonical
      ..write('|')
      ..write(k)
      ..write('=')
      ..write(fields[k]);
  }
  var hash = 0x811c9dc5;
  for (final b in utf8.encode(canonical.toString())) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Tags that are added by the app (merging, community, annotations) and are
/// therefore not part of an OSM entry's source data.
bool isDerivedTag(String key) =>
    key == fingerprintTag ||
    key == 'aliases' ||
    key == 'osm:element' ||
    key.startsWith('community') ||
    key.startsWith('official') ||
    key.startsWith('temporarily_closed');
