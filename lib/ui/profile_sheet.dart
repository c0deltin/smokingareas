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
                Text('Profil', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(current.displayName.characters.first
                        .toUpperCase()),
                  ),
                  title: Text(current.displayName),
                  subtitle: const Text('Aktives Profil'),
                  trailing: IconButton(
                    tooltip: 'Umbenennen',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final name = await _askName(context, current.displayName);
                      if (name != null) await community.renameCurrentUser(name);
                    },
                  ),
                ),
                const Divider(),
                Text('Profile auf diesem Gerät',
                    style: theme.textTheme.titleSmall),
                for (final u in community.users)
                  if (u.id != current.id)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(u.displayName),
                      trailing: TextButton(
                        onPressed: () => community.switchUser(u.id),
                        child: const Text('Wechseln'),
                      ),
                    ),
                TextButton.icon(
                  onPressed: () async {
                    final name = await _askName(context, '');
                    if (name != null) await community.createUser(name);
                  },
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Neues Profil anlegen'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bewertungen, Fotos und Meldungen werden derzeit nur lokal '
                  'auf diesem Gerät gespeichert und dem aktiven Profil '
                  'zugeordnet. Mit mehreren Profilen lässt sich z. B. testen, '
                  'dass ein Spot nach drei „Gibt es nicht mehr“-Meldungen '
                  'verschwindet.',
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
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
