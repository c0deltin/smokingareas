import 'package:flutter/material.dart';

import '../data/cities.dart';
import '../models/city.dart';

Future<City?> showCityPicker(BuildContext context, {City? selected}) {
  return showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _CityPicker(selected: selected, controller: controller),
    ),
  );
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({this.selected, required this.controller});
  final City? selected;
  final ScrollController controller;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final cities = kCities
        .where((c) =>
            q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.nameJa.contains(_query) ||
            c.prefecture.toLowerCase().contains(q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Stadt oder Präfektur suchen',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.controller,
            itemCount: cities.length,
            itemBuilder: (context, i) {
              final c = cities[i];
              return ListTile(
                leading: const Icon(Icons.location_city),
                title: Text(c.name),
                subtitle: Text('${c.nameJa} · ${c.prefecture}'),
                trailing: c.id == widget.selected?.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(c),
              );
            },
          ),
        ),
      ],
    );
  }
}
