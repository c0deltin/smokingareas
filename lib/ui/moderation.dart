import 'package:flutter/material.dart';

import '../community/community_service.dart';
import '../community/models.dart';
import '../i18n.dart';
import 'sign_in_sheet.dart';

/// "⋮" menu on user content (spot, rating, photo): report it or block its
/// author. Nothing to show for the user's own content.
class ContentMenu extends StatelessWidget {
  const ContentMenu({
    super.key,
    required this.community,
    required this.target,
    required this.targetId,
    required this.authorId,
    required this.authorName,
    this.onBlocked,
    this.iconSize = 18,
  });

  final CommunityService community;
  final ReportTarget target;
  final String targetId;
  final String authorId;
  final String authorName;
  final VoidCallback? onBlocked;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (authorId.isNotEmpty && authorId == community.currentUser?.id) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip: context.l10n.more,
      iconSize: iconSize,
      padding: EdgeInsets.zero,
      onSelected: (v) async {
        if (v == 'report') {
          await showReportDialog(context, community, target, targetId);
        } else if (await confirmBlock(
            context, community, authorId, authorName)) {
          onBlocked?.call();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(context.l10n.report),
          ),
        ),
        if (authorId.isNotEmpty)
          PopupMenuItem(
            value: 'block',
            child: ListTile(
              leading: const Icon(Icons.block),
              title: Text(context.l10n.blockName(authorName)),
            ),
          ),
      ],
    );
  }
}

/// Asks for a reason and sends the report. Returns true when it was sent.
Future<bool> showReportDialog(BuildContext context, CommunityService community,
    ReportTarget target, String targetId) async {
  if (!await ensureSignedIn(context, community,
          reason: context.l10n.signInToReportContent) ||
      !context.mounted) {
    return false;
  }
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => const _ReportDialog(),
  );
  if (reason == null || !context.mounted) return false;
  final sent = await contribute(
      context,
      community,
      () => withProgress(
          context, () => community.report(target, targetId, reason),
          label: context.l10n.sending));
  if (sent && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.thanksReportReviewed)));
  }
  return sent;
}

/// Asks before blocking. Returns true when the user was blocked.
Future<bool> confirmBlock(BuildContext context, CommunityService community,
    String userId, String name) async {
  if (!await ensureSignedIn(context, community,
          reason: context.l10n.signInToBlock) ||
      !context.mounted) {
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.blockNameQuestion(name)),
      content: Text(context.l10n.blockExplain),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.block),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  return contribute(context, community,
      () => withProgress(context, () => community.block(userId)));
}

String _reasonLabel(BuildContext context, String reason) {
  final l = context.l10n;
  return switch (reportReasons.indexOf(reason)) {
    0 => l.reasonOffensive,
    1 => l.reasonSpam,
    2 => l.reasonPersonalData,
    3 => l.reasonWrong,
    _ => l.reasonOther,
  };
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.report),
      scrollable: true,
      content: RadioGroup<String>(
        groupValue: _reason,
        onChanged: (v) => setState(() => _reason = v),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final r in reportReasons)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: r,
              // Sent in English (for the moderators), shown translated.
              title: Text(_reasonLabel(context, r)),
            ),
          TextField(
            controller: _details,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: context.l10n.detailsOptional,
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () {
                  final details = _details.text.trim();
                  Navigator.pop(
                      context,
                      details.isEmpty
                          ? _reason
                          : '$_reason: $details');
                },
          child: Text(context.l10n.send),
        ),
      ],
    );
  }
}
