import 'package:flutter/material.dart';

import '../models/smoking_area.dart';

/// Map colour of a category: green for smoking areas (darker when indoor),
/// blue for public toilets, orange for trash cans.
Color categoryColor(SpotCategory c, {bool indoor = false}) => switch (c) {
      SpotCategory.smoking =>
        indoor ? const Color(0xFF00695C) : const Color(0xFF26A69A),
      SpotCategory.toilet => const Color(0xFF1E63D6),
      SpotCategory.bin => const Color(0xFFEF6C00),
    };

IconData categoryIcon(SpotCategory c) => switch (c) {
      SpotCategory.smoking => Icons.smoking_rooms,
      SpotCategory.toilet => Icons.wc,
      SpotCategory.bin => Icons.delete_outline,
    };

/// Where a map entry comes from – shown as the marker ring.
enum SpotOrigin {
  /// OpenStreetMap only (white ring).
  osm,

  /// Official list of a city or ward (gold ring).
  official,

  /// Reported by a user (pink ring).
  community,
}

Color originRingColor(SpotOrigin o) => switch (o) {
      SpotOrigin.osm => Colors.white,
      SpotOrigin.official => const Color(0xFFFFCA28),
      SpotOrigin.community => Colors.pinkAccent,
    };

/// The marker used on the map and in the legend: fill = category (grey when
/// temporarily closed), ring = origin, pause badge = temporarily closed,
/// orange trash can badge = a trash can is part of the spot.
///
/// The map draws the same [SpotMarkerPainter] into bitmaps, so the legend
/// always matches the map.
class SpotMarker extends StatelessWidget {
  const SpotMarker({
    super.key,
    required this.category,
    this.indoor = false,
    this.origin = SpotOrigin.osm,
    this.closed = false,
    this.bin = false,
  });

  factory SpotMarker.fromArea(SmokingArea area, {Key? key}) => SpotMarker(
        key: key,
        category: area.category,
        indoor: area.isIndoor == true,
        origin: area.isOfficial
            ? SpotOrigin.official
            : (area.tags['community'] == 'yes'
                ? SpotOrigin.community
                : SpotOrigin.osm),
        closed: area.isTemporarilyClosed,
        bin: area.category != SpotCategory.bin && area.hasBin == true,
      );

  /// Diameter of the marker circle in logical pixels.
  static const double size = 36;

  final SpotCategory category;
  final bool indoor;
  final SpotOrigin origin;
  final bool closed;
  final bool bin;

  /// Identifies the look; markers with the same key share one bitmap.
  String get styleKey =>
      '${category.name}-$indoor-${origin.name}-$closed-$bin';

  SpotMarkerPainter get painter => SpotMarkerPainter(this);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(size), painter: painter);
}

/// Draws a [SpotMarker] centred in the canvas. The badges may extend up to
/// [badgeOverhang] beyond the circle.
class SpotMarkerPainter extends CustomPainter {
  SpotMarkerPainter(this.marker);

  final SpotMarker marker;

  static const double badgeOverhang = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = SpotMarker.size / 2;
    canvas.drawCircle(
        c.translate(0, 1),
        r,
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = marker.closed
              ? Colors.grey.shade500
              : categoryColor(marker.category, indoor: marker.indoor));
    final ring = marker.origin == SpotOrigin.osm ? 2.0 : 3.0;
    canvas.drawCircle(
        c,
        r - ring / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring
          ..color = originRingColor(marker.origin));
    paintIcon(canvas, categoryIcon(marker.category), c, 20, Colors.white);
    if (marker.closed) {
      final b = c.translate(r - 4 + 2, -r + 4 - 2);
      canvas.drawCircle(b, 8, Paint()..color = Colors.white);
      paintIcon(canvas, Icons.pause_circle_filled, b, 16, Colors.red);
    }
    if (marker.bin) {
      final b = c.translate(r - 4 + 2, r - 4 + 2);
      canvas.drawCircle(b, 8, Paint()..color = Colors.white);
      canvas.drawCircle(
          b, 6.5, Paint()..color = categoryColor(SpotCategory.bin));
      paintIcon(canvas, categoryIcon(SpotCategory.bin), b, 10, Colors.white);
    }
  }

  @override
  bool shouldRepaint(SpotMarkerPainter old) =>
      old.marker.styleKey != marker.styleKey;
}

/// Bubble for several spots of one category (marker clustering).
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({super.key, required this.category, required this.count});

  final SpotCategory category;
  final int count;

  static const double size = 42;

  /// Text in the bubble; large counts are rounded so bitmaps can be shared.
  static String label(int count) => switch (count) {
        < 100 => '$count',
        < 1000 => '${count ~/ 100 * 100}+',
        _ => '${count ~/ 1000}k+',
      };

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size.square(size),
        painter: ClusterBubblePainter(category, label(count)),
      );
}

class ClusterBubblePainter extends CustomPainter {
  ClusterBubblePainter(this.category, this.label);

  final SpotCategory category;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = ClusterBubble.size / 2;
    canvas.drawCircle(c, r, Paint()..color = categoryColor(category));
    canvas.drawCircle(
        c,
        r - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: label.length > 3 ? 12 : 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(ClusterBubblePainter old) =>
      old.category != category || old.label != label;
}

/// Paints a Material icon glyph centred on [center].
void paintIcon(
    Canvas canvas, IconData icon, Offset center, double size, Color color) {
  final text = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        inherit: false,
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
}
