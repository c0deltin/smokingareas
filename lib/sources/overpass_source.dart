import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/city.dart';
import '../models/smoking_area.dart';
import 'smoking_area_source.dart';

/// Smoking areas from OpenStreetMap, queried live through the public
/// Overpass API.
///
/// In Japan, public smoking spots (喫煙所) are mapped as
/// `amenity=smoking_area`; dedicated smoking rooms / booths sometimes as
/// `amenity=smoking_room` or with `smoking=dedicated`.
class OverpassSource extends SmokingAreaSource {
  OverpassSource({http.Client? client, List<Uri>? endpoints})
      : _client = client ?? http.Client(),
        endpoints = endpoints ?? defaultEndpoints;

  /// Public Overpass instances, tried in order.
  static final List<Uri> defaultEndpoints = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.kumi.systems/api/interpreter'),
    Uri.parse('https://maps.mail.ru/osm/tools/overpass/api/interpreter'),
  ];

  static const userAgent =
      'smokingareas/1.0 (+https://github.com/c0deltin/smokingareas)';

  final http.Client _client;
  final List<Uri> endpoints;

  @override
  String get id => 'osm';

  @override
  String get displayName => 'OpenStreetMap';

  @override
  String get attribution => '© OpenStreetMap-Mitwirkende (ODbL)';

  static String buildQuery(GeoBounds b) {
    final bbox = b.toOverpass();
    return '[out:json][timeout:90];\n'
        '(\n'
        '  nwr["amenity"~"^(smoking_area|smoking_room)\$"]($bbox);\n'
        '  nwr["smoking"="dedicated"]($bbox);\n'
        // Publicly usable toilets (not private / customers only).
        '  nwr["amenity"="toilets"]["access"!~"^(private|no|customers|permit)\$"]($bbox);\n'
        ');\n'
        'out center tags;';
  }

  @override
  Future<List<SmokingArea>> fetch(GeoBounds bounds) async {
    final query = buildQuery(bounds);
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        final response = await _client
            .post(
              endpoint,
              headers: {
                'User-Agent': userAgent,
                'Accept': 'application/json',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 100));
        if (response.statusCode == 200) {
          return parse(utf8.decode(response.bodyBytes));
        }
        lastError = 'HTTP ${response.statusCode} from ${endpoint.host}';
      } on TimeoutException {
        lastError = 'Timeout at ${endpoint.host}';
      } catch (e) {
        lastError = e;
      }
    }
    throw SourceException('OpenStreetMap unreachable: $lastError');
  }

  /// Parses an Overpass JSON response.
  static List<SmokingArea> parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final elements = (json['elements'] as List?) ?? const [];
    final result = <SmokingArea>[];
    for (final raw in elements) {
      final e = raw as Map<String, dynamic>;
      final type = e['type'] as String?;
      final osmId = e['id'];
      double? lat = (e['lat'] as num?)?.toDouble();
      double? lon = (e['lon'] as num?)?.toDouble();
      final center = e['center'] as Map<String, dynamic>?;
      if ((lat == null || lon == null) && center != null) {
        lat = (center['lat'] as num?)?.toDouble();
        lon = (center['lon'] as num?)?.toDouble();
      }
      if (type == null || osmId == null || lat == null || lon == null) {
        continue;
      }
      final tags = ((e['tags'] as Map<String, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k, v.toString()));
      result.add(SmokingArea(
        id: 'osm:$type/$osmId',
        position: LatLng(lat, lon),
        source: 'OpenStreetMap',
        name: tags['name'],
        tags: tags,
      ).withOsmFingerprint());
    }
    return result;
  }
}
