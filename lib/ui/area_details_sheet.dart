import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../community/community_service.dart';
import '../community/models.dart';
import '../models/smoking_area.dart';
import 'community_section.dart';
import 'moderation.dart';
import 'spot_style.dart';

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
        v == null ? 'unknown' : (v ? yes : no);

    final rows = <(IconData, String, String)>[
      if (distance != null)
        (Icons.near_me, 'Distance', formatDistance(distance)),
      if (area.address != null) (Icons.place_outlined, 'Address', area.address!),
      if (area.isApproximate)
        (Icons.gps_not_fixed, 'Position',
            'approximate (from the address, ± approx. 50 m)'),
      if (!area.isToilet && area.roomCount > 1)
        (Icons.layers_outlined, 'Smoking rooms',
            '${area.roomCount} in the same building'),
      if (!area.isToilet) ...[
        (Icons.meeting_room_outlined, 'Type',
            yesNo(area.isIndoor, 'Smoking room (indoors)', 'Outdoors')),
        (Icons.roofing, 'Covered', yesNo(area.isCovered, 'yes', 'no')),
      ],
      if (area.isToilet) ...[
        (Icons.accessible, 'Wheelchair accessible',
            yesNo(area.wheelchair, 'yes', 'no')),
        (Icons.baby_changing_station, 'Baby changing',
            yesNo(area.changingTable, 'yes', 'no')),
      ],
      if (area.isPublic != null || area.accessNote != null)
        (
          Icons.lock_open_outlined,
          'Access',
          [
            if (area.isPublic != null)
              area.isPublic!
                  ? 'public'
                  : 'not public (ticket, entry fee or purchase needed)',
            if (area.accessNote != null) area.accessNote!,
          ].join(' – '),
        ),
      (Icons.payments_outlined, 'Fee',
          yesNo(area.requiresFee, 'yes', 'no')),
      if (area.openingHours != null)
        (Icons.schedule, 'Opening hours', area.openingHours!),
      if (area.operator != null) (Icons.business, 'Operator', area.operator!),
      if (area.description != null)
        (Icons.info_outline, 'Note', area.description!),
      if (area.tags['community:by'] != null)
        (Icons.person_outline, 'Reported by', area.tags['community:by']!),
      (Icons.storage, 'Source',
          area.isOfficial ? '${area.source} (official)' : area.source),
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
                  backgroundColor: categoryColor(area.category,
                      indoor: area.isIndoor == true),
                  child: Icon(
                      categoryIcon(area.category),
                      color: Colors.white),
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
                // Places reported by users can be reported to moderators.
                if (community != null && area.tags['community'] == 'yes')
                  ContentMenu(
                    community: community!,
                    target: ReportTarget.spot,
                    targetId: area.id,
                    authorId: area.tags['community:by_id'] ?? '',
                    authorName: area.tags['community:by'] ?? 'this user',
                    onBlocked: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (community != null)
              ListenableBuilder(
                listenable: community!,
                builder: (context, _) {
                  final current = community!.annotate(area);
                  return current.isTemporarilyClosed
                      ? ClosedBanner(area: current)
                      : const SizedBox.shrink();
                },
              )
            else if (area.isTemporarilyClosed)
              ClosedBanner(area: area),
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
                      label: const Text('City'),
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
                    content: Text('Thanks! The place was removed after '
                        'community reports.'),
                  ));
                },
              ),
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Red notice for temporarily closed spots.
class ClosedBanner extends StatelessWidget {
  const ClosedBanner({super.key, required this.area});
  final SmokingArea area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = area.closedUntil;
    final note = area.closedNote;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.pause_circle_filled, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Temporarily closed',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer)),
            if (note != null)
              Text(note,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer)),
            if (until != null)
              Text('expected until ${formatDate(until)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ]),
        ),
      ]),
    );
  }
}
