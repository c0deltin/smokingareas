import 'dart:io';

import 'package:flutter/material.dart';

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
  });

  final SpotCategory category;
  final bool? wheelchair;
  final bool? changingTable;

  /// Trash cans: accepted waste (empty = not specified).
  final Set<WasteType> waste;
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
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('What do you want to report?'),
        ),
        for (final c in SpotCategory.values)
          ListTile(
            leading: Icon(categoryIcon(c), color: categoryColor(c)),
            title: Text(c.label),
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
  File? _photo;

  bool get _toilet => widget.category == SpotCategory.toilet;
  bool get _smoking => widget.category == SpotCategory.smoking;
  bool get _bin => widget.category == SpotCategory.bin;
  bool get _editing => widget.initial != null;

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
            Text(
                _editing
                    ? 'Edit ${widget.category.label.toLowerCase()}'
                    : 'Report ${widget.category.label.toLowerCase()}',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'Name / place',
                hintText: switch (widget.category) {
                  SpotCategory.toilet => 'e.g. "Toilet at the park entrance"',
                  SpotCategory.bin => 'e.g. "Bins next to the vending machines"',
                  SpotCategory.smoking =>
                    'e.g. "Smoking corner next to FamilyMart"',
                },
                border: const OutlineInputBorder(),
              ),
            ),
            if (_toilet) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _wheelchair,
                onChanged: (v) => setState(() => _wheelchair = v ?? false),
                title: const Text('Wheelchair accessible'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _changingTable,
                onChanged: (v) => setState(() => _changingTable = v ?? false),
                title: const Text('Baby changing'),
              ),
            ],
            if (_bin) ...[
              const SizedBox(height: 8),
              Text('Accepts', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                for (final t in WasteType.values)
                  FilterChip(
                    label: Text(t.label),
                    selected: _waste.contains(t),
                    onSelected: (on) => setState(
                        () => on ? _waste.add(t) : _waste.remove(t)),
                  ),
              ]),
            ],
            if (_smoking) ...[
            const SizedBox(height: 8),
            Text('Type', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<bool?>(
              segments: const [
                ButtonSegment(value: false, label: Text('Outdoors')),
                ButtonSegment(value: true, label: Text('Smoking room')),
                ButtonSegment(value: null, label: Text('Not sure')),
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
                title: const Text('Covered'),
              ),
            ],
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _public,
              onChanged: (v) => setState(() => _public = v ?? true),
              title: const Text('Publicly accessible'),
              subtitle: const Text('no ticket, entry fee or purchase needed'),
            ),
            if (!_public) ...[
              TextField(
                controller: _accessNote,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Access (optional)',
                  hintText: 'e.g. station platform – ticket only, inside a museum',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 280,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: _bin
                    ? 'Where exactly, how to find it …'
                    : 'Opening hours, ashtray, access …',
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
                label: Text(_photo == null ? 'Add photo' : 'Change photo'),
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
                  publicAccess: _public,
                  accessNote: _public ? null : _accessNote.text,
                  photo: _photo,
                ),
              ),
              icon: Icon(_editing ? Icons.save_outlined : Icons.send),
              label: Text(_editing ? 'Save' : 'Report'),
            ),
            const SizedBox(height: 4),
            if (!_editing) Text(
              'Reported spots are visible right away. If enough users report '
              'that a spot does not exist, it is removed again.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
