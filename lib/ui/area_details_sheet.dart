import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../community/community_service.dart';
import '../models/smoking_area.dart';
import 'community_section.dart';

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

Future<void> showAreaDetails(
  BuildContext context,
  SmokingArea area, {
  LatLng? userPosition,
  CommunityService? community,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => AreaDetailsSheet(
        area: area,
        userPosition: userPosition,
        community: community,
        scrollController: controller,
      ),
    ),
  );
}

class AreaDetailsSheet extends StatelessWidget {
  const AreaDetailsSheet({
    super.key,
    required this.area,
    this.userPosition,
    this.community,
    this.scrollController,
  });

  final SmokingArea area;
  final LatLng? userPosition;
  final CommunityService? community;
  final ScrollController? scrollController;

  Uri get _routeUri {
    final dest = '${area.latitude},${area.longitude}';
    if (Platform.isIOS) {
      return Uri.parse('https://maps.apple.com/?daddr=$dest&dirflg=w');
    }
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=walking',
    );
  }

  Uri? get _officialUri {
    final url = area.officialUrl;
    return url == null ? null : Uri.tryParse(url);
  }

  Uri? get _osmUri {
    final element = area.osmElement;
    if (element != null) {
      return Uri.parse('https://www.openstreetmap.org/$element');
    }
    final website = area.tags['website'] ?? area.tags['url'];
    return website == null ? null : Uri.tryParse(website);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = userPosition == null
        ? null
        : const Distance()(userPosition!, area.position);
    final nameJa = area.tags['name:ja'];
    final nameEn = area.tags['name:en'];

    String yesNo(bool? v, String yes, String no) =>
        v == null ? 'unbekannt' : (v ? yes : no);

    final rows = <(IconData, String, String)>[
      if (distance != null)
        (Icons.near_me, 'Entfernung', formatDistance(distance)),
      if (area.address != null) (Icons.place_outlined, 'Adresse', area.address!),
      if (area.isApproximate)
        (Icons.gps_not_fixed, 'Position',
            'ungefähr (aus der Adresse ermittelt, ± ca. 50 m)'),
      if (area.roomCount > 1)
        (Icons.layers_outlined, 'Raucherräume',
            '${area.roomCount} im selben Gebäude'),
      (Icons.meeting_room_outlined, 'Art',
          yesNo(area.isIndoor, 'Raucherraum (innen)', 'im Freien')),
      (Icons.roofing, 'Überdacht', yesNo(area.isCovered, 'ja', 'nein')),
      if (area.isPublic != null || area.accessNote != null)
        (
          Icons.lock_open_outlined,
          'Zugang',
          [
            if (area.isPublic != null)
              area.isPublic!
                  ? 'öffentlich'
                  : 'nicht öffentlich (Ticket/Eintritt/Einkauf nötig)',
            if (area.accessNote != null) area.accessNote!,
          ].join(' – '),
        ),
      (Icons.payments_outlined, 'Kostenpflichtig',
          yesNo(area.requiresFee, 'ja', 'nein')),
      if (area.openingHours != null)
        (Icons.schedule, 'Öffnungszeiten', area.openingHours!),
      if (area.operator != null) (Icons.business, 'Betreiber', area.operator!),
      if (area.description != null)
        (Icons.info_outline, 'Hinweis', area.description!),
      if (area.tags['community:by'] != null)
        (Icons.person_outline, 'Gemeldet von', area.tags['community:by']!),
      (Icons.storage, 'Quelle',
          area.isOfficial ? '${area.source} (offiziell)' : area.source),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.smoking_rooms,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(area.title, style: theme.textTheme.titleLarge),
                      if (nameJa != null && nameJa != area.title)
                        Text(nameJa, style: theme.textTheme.bodyMedium),
                      if (nameEn != null && nameEn != area.title)
                        Text(nameEn, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: Text(value,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => launchUrl(_routeUri,
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Route'),
                  ),
                ),
                if (_officialUri != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(_officialUri!,
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.account_balance_outlined),
                      label: const Text('Stadt'),
                    ),
                  ),
                ],
                if (_osmUri != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(_osmUri!,
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('OSM'),
                    ),
                  ),
                ],
              ],
            ),
            if (community != null)
              CommunitySection(
                area: area,
                community: community!,
                onRemoved: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Danke! Der Raucherbereich wurde nach den '
                        'Meldungen der Community entfernt.'),
                  ));
                },
              ),
          ],
        ),
      ),
    );
  }
}
