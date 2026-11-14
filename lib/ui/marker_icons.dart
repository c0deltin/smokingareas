import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/smoking_area.dart';
import 'spot_style.dart';
import 'user_location_marker.dart';

/// Map marker bitmaps, drawn with the same painters as the legend and cached
/// by look (a few dozen bitmaps for thousands of markers).
class MarkerIcons {
  MarkerIcons(this.pixelRatio);

  final double pixelRatio;
  final _cache = <String, BitmapDescriptor>{};
  final _pending = <String, Future<BitmapDescriptor>>{};

  /// Canvas size of a spot marker incl. room for the pause badge.
  static const double spotCanvas =
      SpotMarker.size + 2 * SpotMarkerPainter.badgeOverhang;
  static const double coneCanvas = UserLocationMarker.size;

  BitmapDescriptor? spot(SpotMarker m) => _cache['spot:${m.styleKey}'];
  BitmapDescriptor? cluster(SpotCategory c, String label) =>
      _cache['cluster:${c.name}:$label'];
  BitmapDescriptor? get dot => _cache['dot'];
  BitmapDescriptor? cone(double spread) => _cache['cone:${_spreadStep(spread)}'];

  static int _spreadStep(double spread) => (spread / 5).round() * 5;

  /// Renders all spot looks plus the location symbols.
  Future<void> prepareBase() => Future.wait([
        for (final c in SpotCategory.values)
          for (final indoor in [false, true])
            for (final o in SpotOrigin.values)
              for (final closed in [false, true])
                for (final bin in [false, if (c != SpotCategory.bin) true])
                  ensureSpot(SpotMarker(
                      category: c,
                      indoor: indoor,
                      origin: o,
                      closed: closed,
                      bin: bin)),
        _render('dot', LocationDotPainter.size, LocationDotPainter()),
      ]);

  Future<BitmapDescriptor> ensureSpot(SpotMarker m) =>
      _render('spot:${m.styleKey}', spotCanvas, m.painter);

  Future<BitmapDescriptor> ensureCluster(SpotCategory c, String label) =>
      _render('cluster:${c.name}:$label', ClusterBubble.size,
          ClusterBubblePainter(c, label));

  /// Cone pointing north; the map rotates the (flat) marker to the heading.
  Future<BitmapDescriptor> ensureCone(double spread) {
    final step = _spreadStep(spread);
    return _render(
        'cone:$step',
        coneCanvas,
        HeadingConePainter(
            headingDegrees: 0,
            spreadDegrees: step.toDouble(),
            color: Colors.blue));
  }

  Future<BitmapDescriptor> _render(
      String key, double logicalSize, CustomPainter painter) {
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    return _pending[key] ??= () async {
      final px = (logicalSize * pixelRatio).ceil();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(pixelRatio);
      painter.paint(canvas, Size.square(logicalSize));
      final image = await recorder.endRecording().toImage(px, px);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final icon = BitmapDescriptor.bytes(png!.buffer.asUint8List(),
          width: logicalSize, height: logicalSize);
      _pending.remove(key);
      return _cache[key] = icon;
    }();
  }
}
