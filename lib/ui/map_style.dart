import 'package:flutter/material.dart';

/// Google Maps style for dark mode (null = the default light map). Muted
/// colours so the coloured markers stay the brightest thing on the map.
String? mapStyleFor(Brightness brightness) =>
    brightness == Brightness.dark ? darkMapStyle : null;

const darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2330"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#9aa4b5"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1d2330"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#3a4354"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#232a38"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#1f2f2b"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c3444"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1a1f2a"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3b4558"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8590a3"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#283042"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#b3bccb"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f1726"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e5d78"}]}
]
''';
