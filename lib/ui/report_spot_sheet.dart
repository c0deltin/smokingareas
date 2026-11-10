import 'dart:io';

import 'package:flutter/material.dart';

import 'community_section.dart';

/// Data entered for a new spot.
class SpotReportInput {
  const SpotReportInput({
    required this.name,
    this.description,
    this.indoor,
    this.covered,
    this.photo,
  });

  final String name;
  final String? description;
  final bool? indoor;
  final bool? covered;
  final File? photo;
}

Future<SpotReportInput?> showReportSpotSheet(BuildContext context) {
  return showModalBottomSheet<SpotReportInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: const _ReportSpotForm(),
    ),
  );
}

class _ReportSpotForm extends StatefulWidget {
  const _ReportSpotForm();

  @override
  State<_ReportSpotForm> createState() => _ReportSpotFormState();
}

class _ReportSpotFormState extends State<_ReportSpotForm> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool? _indoor;
  bool? _covered;
  File? _photo;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
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
            Text('Raucherbereich melden', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Name / Ort',
                hintText: 'z. B. „Raucherecke neben FamilyMart“',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Art', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<bool?>(
              segments: const [
                ButtonSegment(value: false, label: Text('Im Freien')),
                ButtonSegment(value: true, label: Text('Raucherraum')),
                ButtonSegment(value: null, label: Text('Weiß nicht')),
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
                title: const Text('Überdacht'),
              ),
            ],
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Hinweis (optional)',
                hintText: 'Öffnungszeiten, Aschenbecher, Zugang …',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final file = await pickPhoto(context);
                  if (file != null) setState(() => _photo = file);
                },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_photo == null ? 'Foto hinzufügen' : 'Foto ändern'),
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
                  indoor: _indoor,
                  covered: _indoor == true ? null : _covered,
                  photo: _photo,
                ),
              ),
              icon: const Icon(Icons.send),
              label: const Text('Melden'),
            ),
            const SizedBox(height: 4),
            Text(
              'Gemeldete Spots sind sofort sichtbar. Melden genug Nutzer, '
              'dass es ihn nicht gibt, wird er wieder entfernt.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
