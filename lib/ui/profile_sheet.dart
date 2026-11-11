import 'package:flutter/material.dart';

import '../community/community_service.dart';

/// Local profiles: rename the active one, create more, switch between them.
Future<void> showProfileSheet(BuildContext context, CommunityService community) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        final theme = Theme.of(context);
        final current = community.currentUser;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Profile', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(current.displayName.characters.first
                        .toUpperCase()),
                  ),
                  title: Text(current.displayName),
                  subtitle: const Text('Active profile'),
                  trailing: IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final name = await _askName(context, current.displayName);
                      if (name != null) await community.renameCurrentUser(name);
                    },
                  ),
                ),
                const Divider(),
                Text('Profiles on this device',
                    style: theme.textTheme.titleSmall),
                for (final u in community.users)
                  if (u.id != current.id)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(u.displayName),
                      trailing: TextButton(
                        onPressed: () => community.switchUser(u.id),
                        child: const Text('Switch'),
                      ),
                    ),
                TextButton.icon(
                  onPressed: () async {
                    final name = await _askName(context, '');
                    if (name != null) await community.createUser(name);
                  },
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Create profile'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ratings, photos and reports are currently stored only on '
                  'this device and assigned to the active profile. Several '
                  'profiles let you try out e.g. that a spot disappears after '
                  'three "gone" reports.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<String?> _askName(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
