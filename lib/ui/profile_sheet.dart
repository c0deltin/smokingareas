import 'package:flutter/material.dart';

import '../community/community_service.dart';
import 'sign_in_sheet.dart';

/// Account (server backend: sign in / out, rename, delete account) or, in
/// development without a server, local profiles.
Future<void> showProfileSheet(BuildContext context, CommunityService community) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        if (!community.hasLocalProfiles) {
          return AccountView(community: community);
        }
        final theme = Theme.of(context);
        final current = community.currentUser!;
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

/// Account of a signed-in user (or the invitation to sign in).
class AccountView extends StatelessWidget {
  const AccountView({super.key, required this.community});
  final CommunityService community;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = community.currentUser;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Account', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (user == null) ...[
              const Text('You are using the app without an account. Sign '
                  'in with Apple or Google to rate, report and add photos.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => showSignInSheet(context, community),
                child: const Text('Sign in'),
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(user.displayName.characters.first.toUpperCase()),
                ),
                title: Text(user.displayName),
                subtitle: const Text('Shown with your contributions'),
                trailing: IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final name = await _askName(context, user.displayName);
                    if (name == null || !context.mounted) return;
                    await contribute(context, community,
                        () => community.renameCurrentUser(name));
                  },
                ),
              ),
              if (community.blockedUsers.isNotEmpty) ...[
                const Divider(),
                Text('Blocked users', style: theme.textTheme.titleSmall),
                for (final id in community.blockedUsers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.block),
                    title: Text(community.userName(id)),
                    trailing: TextButton(
                      onPressed: () => contribute(
                          context, community, () => community.unblock(id)),
                      child: const Text('Unblock'),
                    ),
                  ),
              ],
              const Divider(),
              OutlinedButton.icon(
                onPressed: community.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
                onPressed: () => _deleteAccount(context),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete account'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Your account, ratings, photos, votes and closure reports are '
          'deleted for good. Places you reported stay on the map without '
          'your name.',
        ),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await community.deleteAccount();
      messenger.showSnackBar(
          const SnackBar(content: Text('Your account was deleted.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not delete the account – please try again.')));
    }
  }
}
