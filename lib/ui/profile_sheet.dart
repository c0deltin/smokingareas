import 'package:flutter/material.dart';

import '../community/community_service.dart';
import '../i18n.dart';
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
                Text(context.l10n.profile, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(current.displayName.characters.first
                        .toUpperCase()),
                  ),
                  title: Text(current.displayName),
                  subtitle: Text(context.l10n.activeProfile),
                  trailing: IconButton(
                    tooltip: context.l10n.rename,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final name = await _askName(context, current.displayName);
                      if (name != null) await community.renameCurrentUser(name);
                    },
                  ),
                ),
                const Divider(),
                Text(context.l10n.profilesOnDevice,
                    style: theme.textTheme.titleSmall),
                for (final u in community.users)
                  if (u.id != current.id)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(u.displayName),
                      trailing: TextButton(
                        onPressed: () => community.switchUser(u.id),
                        child: Text(context.l10n.switchProfile),
                      ),
                    ),
                TextButton.icon(
                  onPressed: () async {
                    final name = await _askName(context, '');
                    if (name != null) await community.createUser(name);
                  },
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(context.l10n.createProfile),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.localProfilesNote,
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
      title: Text(context.l10n.name),
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
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(context.l10n.ok),
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
            Text(context.l10n.account, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (user == null) ...[
              Text(context.l10n.noAccountText),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => showSignInSheet(context, community),
                child: Text(context.l10n.signIn),
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(user.displayName.characters.first.toUpperCase()),
                ),
                title: Text(user.displayName),
                subtitle: Text(context.l10n.shownWithContributions),
                trailing: IconButton(
                  tooltip: context.l10n.rename,
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
                Text(context.l10n.blockedUsers,
                    style: theme.textTheme.titleSmall),
                for (final id in community.blockedUsers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.block),
                    title: Text(community.userName(id)),
                    trailing: TextButton(
                      onPressed: () => contribute(
                          context, community, () => community.unblock(id)),
                      child: Text(context.l10n.unblock),
                    ),
                  ),
              ],
              const Divider(),
              OutlinedButton.icon(
                onPressed: community.signOut,
                icon: const Icon(Icons.logout),
                label: Text(context.l10n.signOut),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
                onPressed: () => _deleteAccount(context),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(context.l10n.deleteAccount),
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
        title: Text(context.l10n.deleteAccountQuestion),
        content: Text(context.l10n.deleteAccountText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await community.deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleteFailed)));
    }
  }
}
