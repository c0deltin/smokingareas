import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoking_areas/ui/map_style.dart';

void main() {
  test('dark map style only in dark mode, valid JSON', () {
    expect(mapStyleFor(Brightness.light), isNull);
    final style = jsonDecode(mapStyleFor(Brightness.dark)!) as List;
    expect(style, isNotEmpty);
    expect(style.every((s) => (s as Map).containsKey('stylers')), isTrue);
  });
}
