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
