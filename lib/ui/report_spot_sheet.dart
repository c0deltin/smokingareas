import 'dart:io';

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models/smoking_area.dart';
import 'community_section.dart';
import 'spot_style.dart';

/// Data entered for a new spot.
class SpotReportInput {
  const SpotReportInput({
    required this.name,
    this.description,
    this.indoor,
    this.covered,
    this.publicAccess = true,
    this.accessNote,
    this.photo,
    this.category = SpotCategory.smoking,
    this.wheelchair,
    this.changingTable,
    this.waste = const {},
    this.bin,
  });

  final SpotCategory category;
  final bool? wheelchair;
  final bool? changingTable;

  /// Trash cans: accepted waste (empty = not specified).
  final Set<WasteType> waste;

  /// Smoking areas and toilets: has a trash can (null = not specified).
  final bool? bin;
  final String name;
  final String? description;
  final bool? indoor;
  final bool? covered;
  final bool publicAccess;
  final String? accessNote;
  final File? photo;
}

/// Asks which kind of spot the user wants to report.
Future<SpotCategory?> askSpotCategory(BuildContext context) {
  return showModalBottomSheet<SpotCategory>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(context.l10n.whatToReport),
        ),
        for (final c in SpotCategory.values)
          ListTile(
            leading: Icon(categoryIcon(c), color: categoryColor(c)),
            title: Text(context.l10n.category(c)),
            onTap: () => Navigator.pop(context, c),
          ),
      ]),
    ),
  );
}

/// The form for a new spot, or – with [initial] – for editing an own spot
/// (no photo, "Save" instead of "Report").
Future<SpotReportInput?> showReportSpotSheet(BuildContext context,
    [SpotCategory category = SpotCategory.smoking, SpotReportInput? initial]) {
  return showModalBottomSheet<SpotReportInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ReportSpotForm(category: category, initial: initial),
    ),
  );
}

class _ReportSpotForm extends StatefulWidget {
  const _ReportSpotForm({required this.category, this.initial});
  final SpotCategory category;
  final SpotReportInput? initial;

  @override
  State<_ReportSpotForm> createState() => _ReportSpotFormState();
}

class _ReportSpotFormState extends State<_ReportSpotForm> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _accessNote = TextEditingController();
  bool _public = true;
  bool? _indoor;
  bool? _covered;
  bool _wheelchair = false;
  bool _changingTable = false;
  final Set<WasteType> _waste = {};
  bool _hasBin = false;
  File? _photo;

  bool get _toilet => widget.category == SpotCategory.toilet;
  bool get _smoking => widget.category == SpotCategory.smoking;
  bool get _bin => widget.category == SpotCategory.bin;
  bool get _editing => widget.initial != null;

  String _title(BuildContext context) {
    final l = context.l10n;
    return switch ((widget.category, _editing)) {
      (SpotCategory.smoking, false) => l.reportTitleSmoking,
      (SpotCategory.toilet, false) => l.reportTitleToilet,
      (SpotCategory.bin, false) => l.reportTitleBin,
      (SpotCategory.smoking, true) => l.editTitleSmoking,
      (SpotCategory.toilet, true) => l.editTitleToilet,
      (SpotCategory.bin, true) => l.editTitleBin,
    };
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = i.name;
      _description.text = i.description ?? '';
      _accessNote.text = i.accessNote ?? '';
      _public = i.publicAccess;
      _indoor = i.indoor;
      _covered = i.covered;
      _wheelchair = i.wheelchair ?? false;
      _changingTable = i.changingTable ?? false;
      _waste.addAll(i.waste);
      _hasBin = i.bin ?? false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _accessNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title(context), style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: context.l10n.namePlace,
                hintText: switch (widget.category) {
                  SpotCategory.toilet => context.l10n.nameHintToilet,
                  SpotCategory.bin => context.l10n.nameHintBin,
                  SpotCategory.smoking => context.l10n.nameHintSmoking,
                },
                border: const OutlineInputBorder(),
              ),
            ),
            if (_toilet) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _wheelchair,
                onChanged: (v) => setState(() => _wheelchair = v ?? false),
                title: Text(context.l10n.wheelchairAccessible),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _changingTable,
                onChanged: (v) => setState(() => _changingTable = v ?? false),
                title: Text(context.l10n.babyChanging),
              ),
            ],
            if (_bin) ...[
              const SizedBox(height: 8),
              Text(context.l10n.accepts, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                for (final t in WasteType.values)
                  FilterChip(
                    label: Text(context.l10n.waste(t)),
                    selected: _waste.contains(t),
                    onSelected: (on) => setState(
                        () => on ? _waste.add(t) : _waste.remove(t)),
                  ),
              ]),
            ],
            if (_smoking) ...[
            const SizedBox(height: 8),
            Text(context.l10n.type, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<bool?>(
              segments: [
                ButtonSegment(
                    value: false, label: Text(context.l10n.outdoors)),
                ButtonSegment(
                    value: true, label: Text(context.l10n.smokingRoom)),
                ButtonSegment(value: null, label: Text(context.l10n.notSure)),
              ],
              selected: {_indoor},
              onSelectionChanged: (v) => setState(() => _indoor = v.first),
            ),
            if (_indoor != true) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _covered ?? false,
                tristate: false,
                onChanged: (v) => setState(() => _covered = v),
                title: Text(context.l10n.covered),
              ),
            ],
            ],
            if (!_bin)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasBin,
                onChanged: (v) => setState(() => _hasBin = v ?? false),
                title: Text(context.l10n.hasTrashCan),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _public,
              onChanged: (v) => setState(() => _public = v ?? true),
              title: Text(context.l10n.publiclyAccessible),
              subtitle: Text(context.l10n.publiclyAccessibleSub),
            ),
            if (!_public) ...[
              TextField(
                controller: _accessNote,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: context.l10n.accessOptional,
                  hintText: context.l10n.accessHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 280,
              decoration: InputDecoration(
                labelText: context.l10n.noteOptional,
                hintText: _bin
                    ? context.l10n.noteHintBin
                    : context.l10n.noteHintDefault,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (!_editing) Row(children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final file = await pickPhoto(context);
                  if (file != null) setState(() => _photo = file);
                },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_photo == null
                    ? context.l10n.addPhoto
                    : context.l10n.changePhoto),
              ),
              const SizedBox(width: 12),
              if (_photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(_photo!,
                      width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 168),
                ),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                SpotReportInput(
                  name: _name.text,
                  description: _description.text,
                  indoor: _smoking ? _indoor : null,
                  covered: !_smoking || _indoor == true ? null : _covered,
                  category: widget.category,
                  wheelchair: _toilet ? _wheelchair : null,
                  changingTable: _toilet ? _changingTable : null,
                  waste: _bin ? {..._waste} : const {},
                  // Unchecked means "not specified" for new spots.
                  bin: _bin ? null : (_hasBin || _editing ? _hasBin : null),
                  publicAccess: _public,
                  accessNote: _public ? null : _accessNote.text,
                  photo: _photo,
                ),
              ),
              icon: Icon(_editing ? Icons.save_outlined : Icons.send),
              label: Text(
                  _editing ? context.l10n.save : context.l10n.report),
            ),
            const SizedBox(height: 4),
            if (!_editing) Text(
              context.l10n.reportedVisibleNote,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
