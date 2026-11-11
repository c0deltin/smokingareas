import 'package:flutter/material.dart';

import '../community/community_service.dart';
import '../community/local_migration.dart';

bool _offeredThisSession = false;

/// Once per app start, for signed-in users with data that earlier versions
/// kept only on this device: upload it to the account or discard it.
Future<void> maybeOfferLocalUpload(BuildContext context,
    CommunityService community, LocalDataMigration? migration) async {
  if (migration == null || !community.isSignedIn || _offeredThisSession) {
    return;
  }
  _offeredThisSession = true;
  if (!await migration.hasData || !context.mounted) return;
  final count = (await migration.plan()).count;
  if (count == 0) {
    await migration.discard();
    return;
  }
  if (!context.mounted) return;
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Contributions on this device'),
      content: Text(
          '$count contribution${count == 1 ? ' was' : 's were'} (places, '
          'ratings, photos, reports) saved only on this device. Upload '
          '${count == 1 ? 'it' : 'them'} to your account so everyone can '
          'see ${count == 1 ? 'it' : 'them'}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'upload'),
          child: const Text('Upload'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (choice == 'discard') {
    await migration.discard();
    messenger.showSnackBar(const SnackBar(
        content: Text('Removed the contributions from this device.')));
    return;
  }
  if (choice != 'upload') return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Uploading …')),
      ]),
    ),
  );
  MigrationResult result;
  try {
    result = await community.uploadLocalData(migration);
  } catch (e) {
    result = MigrationResult(0, count, e);
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  messenger.showSnackBar(SnackBar(
    content: Text(result.done
        ? 'Uploaded ${result.uploaded} contribution'
            '${result.uploaded == 1 ? '' : 's'}. Thanks!'
        : 'Uploaded ${result.uploaded}, ${result.remaining} left – the rest '
            'is uploaded next time.'),
  ));
}
