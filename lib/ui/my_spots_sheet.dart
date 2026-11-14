import 'package:flutter/material.dart';

import '../community/community_service.dart';
import '../community/models.dart';
import '../models/smoking_area.dart';
import 'area_details_sheet.dart';
import 'report_spot_sheet.dart';
import 'sign_in_sheet.dart';
import 'spot_style.dart';

/// The places the user reported: show on the map, edit, delete.
/// [onShow] moves the map to a place.
Future<void> showMySpotsSheet(BuildContext context, CommunityService community,
    {required void Function(SmokingArea area) onShow}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => MySpotsView(
        community: community,
        onShow: onShow,
        scrollController: controller,
      ),
    ),
  );
}

class MySpotsView extends StatelessWidget {
  const MySpotsView({
    super.key,
    required this.community,
    required this.onShow,
    this.scrollController,
  });

  final CommunityService community;
  final void Function(SmokingArea area) onShow;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        final spots = community.mySpots;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text('My spots', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!community.isSignedIn &&
                community.signInProviders.isNotEmpty) ...[
              const Text('Sign in to see and manage the places you '
                  'reported.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => showSignInSheet(context, community),
                child: const Text('Sign in'),
              ),
            ] else if (spots.isEmpty)
              const Text('You have not reported any places yet. Use the '
                  '"Report a spot" button on the map.')
            else
              for (final s in spots)
                _MySpotTile(spot: s, community: community, onShow: onShow),
          ],
        );
      },
    );
  }
}

class _MySpotTile extends StatelessWidget {
  const _MySpotTile(
      {required this.spot, required this.community, required this.onShow});

  final CommunitySpot spot;
  final CommunityService community;
  final void Function(SmokingArea area) onShow;

  @override
  Widget build(BuildContext context) {
    final category =
        SpotCategory.tryParse(spot.category) ?? SpotCategory.smoking;
    final area = community.areaOf(spot);
    final details = <String>[
      'Reported ${formatDate(spot.createdAt)}',
      if (area != null) ...[
        if (community.ratingFor(area).count > 0)
          '★ ${community.ratingFor(area).average.toStringAsFixed(1)}',
        if (community.photosFor(area).isNotEmpty)
          '${community.photosFor(area).length} photo'
              '${community.photosFor(area).length == 1 ? '' : 's'}',
        if (community.isHidden(area)) 'removed by the community'
        else if (community.annotate(area).isTemporarilyClosed)
          'temporarily closed',
      ],
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: categoryColor(category, indoor: spot.indoor == true),
        child: Icon(categoryIcon(category), color: Colors.white, size: 20),
      ),
      title: Text(spot.name),
      subtitle: Text(details.join(' · ')),
      onTap: area == null ? null : () => _show(context, area),
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (v) => switch (v) {
          'show' => area == null ? null : _show(context, area),
          'edit' => _edit(context, category),
          _ => _delete(context),
        },
        itemBuilder: (_) => [
          if (area != null)
            const PopupMenuItem(
              value: 'show',
              child: ListTile(
                leading: Icon(Icons.map_outlined),
                title: Text('Show on map'),
              ),
            ),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  void _show(BuildContext context, SmokingArea area) {
    Navigator.of(context).pop();
    onShow(area);
  }

  Future<void> _edit(BuildContext context, SpotCategory category) async {
    final input = await showReportSpotSheet(
      context,
      category,
      SpotReportInput(
        name: spot.name,
        description: spot.description,
        indoor: spot.indoor,
        covered: spot.covered,
        publicAccess: spot.publicAccess ?? true,
        accessNote: spot.accessNote,
        category: category,
        wheelchair: spot.wheelchair,
        changingTable: spot.changingTable,
        waste: WasteType.parse(spot.waste),
      ),
    );
    if (input == null || !context.mounted) return;
    await contribute(
      context,
      community,
      () => withProgress(
        context,
        () => community.updateSpot(
          spot.id,
          name: input.name,
          description: input.description,
          indoor: input.indoor,
          covered: input.covered,
          publicAccess: input.publicAccess,
          accessNote: input.accessNote,
          wheelchair: input.wheelchair,
          changingTable: input.changingTable,
          waste: input.waste,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${spot.name}"?'),
        content: const Text('The place is removed from the map for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await contribute(context, community,
        () => withProgress(context, () => community.deleteSpot(spot.id)));
  }
}
