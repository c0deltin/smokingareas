import 'package:flutter/material.dart';

import '../models/smoking_area.dart';

/// Map colour of a category: green for smoking areas (darker when indoor),
/// blue for public toilets.
Color categoryColor(SpotCategory c, {bool indoor = false}) => switch (c) {
      SpotCategory.smoking =>
        indoor ? const Color(0xFF00695C) : const Color(0xFF26A69A),
      SpotCategory.toilet => const Color(0xFF1E63D6),
    };

IconData categoryIcon(SpotCategory c) => switch (c) {
      SpotCategory.smoking => Icons.smoking_rooms,
      SpotCategory.toilet => Icons.wc,
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
/// temporarily closed), ring = origin, pause badge = temporarily closed.
class SpotMarker extends StatelessWidget {
  const SpotMarker({
    super.key,
    required this.category,
    this.indoor = false,
    this.origin = SpotOrigin.osm,
    this.closed = false,
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
      );

  final SpotCategory category;
  final bool indoor;
  final SpotOrigin origin;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: closed
            ? Colors.grey.shade500
            : categoryColor(category, indoor: indoor),
        shape: BoxShape.circle,
        border: Border.all(
          color: originRingColor(origin),
          width: origin == SpotOrigin.osm ? 2 : 3,
        ),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black38)],
      ),
      child: Icon(categoryIcon(category), color: Colors.white, size: 20),
    );
    if (!closed) return marker;
    return Stack(clipBehavior: Clip.none, children: [
      marker,
      const Positioned(
        right: -4,
        top: -4,
        child: CircleAvatar(
          radius: 8,
          backgroundColor: Colors.white,
          child: Icon(Icons.pause_circle_filled, size: 16, color: Colors.red),
        ),
      ),
    ]);
  }
}

/// Bubble for several spots of one category (marker clustering).
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({super.key, required this.category, required this.count});

  final SpotCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: categoryColor(category),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
