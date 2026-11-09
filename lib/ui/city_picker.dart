import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/cities.dart';
import '../data/districts.dart';
import '../models/city.dart';

/// What the user picked: a whole city, or a district within a city.
class PlaceSelection {
  const PlaceSelection({
    required this.city,
    required this.center,
    required this.zoom,
    this.district,
  });

  final City city;
  final District? district;
  final LatLng center;
  final double zoom;

  String get label =>
      district == null ? city.name : '${district!.name} · ${city.name.split(' ').first}';
}

Future<PlaceSelection?> showCityPicker(BuildContext context, {City? selected}) {
  return showModalBottomSheet<PlaceSelection>(
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

  bool _matches(List<String?> fields) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return fields.any((f) => f != null && f.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final districts = kDistricts
        .where((d) => _matches([d.name, d.nameJa, d.ward, cityById(d.cityId)?.name]))
        .toList();
    final cities = kCities
        .where((c) => _matches([c.name, c.nameJa, c.prefecture]))
        .toList();

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Stadt, Viertel oder Präfektur suchen',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            children: [
              if (districts.isNotEmpty) header('Beliebte Viertel'),
              for (final d in districts)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(d.name),
                  subtitle: Text([
                    d.nameJa,
                    if (d.ward != null) 'Bezirk ${d.ward}',
                    cityById(d.cityId)?.name.split(' ').first,
                  ].join(' · ')),
                  onTap: () {
                    final city = cityById(d.cityId);
                    if (city == null) return;
                    Navigator.of(context).pop(PlaceSelection(
                      city: city,
                      district: d,
                      center: d.center,
                      zoom: d.zoom,
                    ));
                  },
                ),
              if (cities.isNotEmpty) header('Städte'),
              for (final c in cities)
                ListTile(
                  leading: const Icon(Icons.location_city),
                  title: Text(c.name),
                  subtitle: Text('${c.nameJa} · ${c.prefecture}'),
                  trailing: c.id == widget.selected?.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(PlaceSelection(
                    city: c,
                    center: c.center,
                    zoom: c.zoom,
                  )),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
