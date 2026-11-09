import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/cities.dart';
import '../models/city.dart';
import '../models/smoking_area.dart';
import '../services/notification_service.dart';
import '../services/proximity_monitor.dart';
import '../services/smoking_area_repository.dart';
import 'area_details_sheet.dart';
import 'city_picker.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.repository,
    required this.monitor,
  });

  final SmokingAreaRepository repository;
  final ProximityMonitor monitor;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  City _city = kCities.first;
  CityAreas? _data;
  bool _loading = false;
  String? _error;
  bool _userPickedCity = false;
  bool _centeredOnUser = false;
  String? _lastAutoCity;

  /// Label of a selected district (Viertel), shown instead of the city name.
  String? _placeLabel;

  SmokingAreaRepository get _repo => widget.repository;
  ProximityMonitor get _monitor => widget.monitor;

  @override
  void initState() {
    super.initState();
    _monitor.addListener(_onMonitorChanged);
    _repo.addListener(_onRepoChanged);
    NotificationService.instance.onTap = _openAreaById;
    _loadCity(_city);
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissions());
  }

  @override
  void dispose() {
    _monitor.removeListener(_onMonitorChanged);
    _repo.removeListener(_onRepoChanged);
    NotificationService.instance.onTap = null;
    super.dispose();
  }

  /// New data from any source/city: redraw the (single, merged) map.
  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  // Markers are rebuilt only when the merged data set changes, not on every
  // position update.
  List<SmokingArea>? _markerSource;
  List<Marker> _markerCache = const [];
  Map<Key, SmokingArea> _markerAreas = const {};

  List<Marker> _markersFor(List<SmokingArea> areas) {
    if (!identical(areas, _markerSource)) {
      _markerSource = areas;
      _markerCache = _markers(areas);
      _markerAreas = {for (final a in areas) ValueKey(a.id): a};
    }
    return _markerCache;
  }

  Future<void> _askPermissions() async {
    if (_monitor.locationState == LocationState.always) return;
    await _monitor.requestPermissions();
  }

  void _onMonitorChanged() {
    final pos = _monitor.position;
    if (pos != null && !_userPickedCity) {
      final city = cityForPosition(pos);
      if (city != null && city.id != _lastAutoCity) {
        _lastAutoCity = city.id;
        if (city.id != _city.id) _selectCity(city, moveMap: false);
      }
      if (!_centeredOnUser && city != null) {
        _centeredOnUser = true;
        _mapController.move(pos, 16);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadCity(City city, {bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.load(city, forceRefresh: force);
      if (!mounted || city.id != _city.id) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      if (data.errors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data.fromCache
              ? 'Offline – zeige gespeicherte Daten vom '
                  '${_formatDate(data.fetchedAt)}.'
              : 'Einige Quellen nicht erreichbar.'),
        ));
      }
    } catch (e) {
      if (!mounted || city.id != _city.id) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _selectCity(City city, {bool moveMap = true}) {
    setState(() {
      if (city.id != _city.id || moveMap) _placeLabel = null;
      _city = city;
      _data = _repo.cached(city.id);
    });
    if (moveMap) _mapController.move(city.center, city.zoom);
    _loadCity(city);
  }

  Future<void> _pickCity() async {
    final place = await showCityPicker(context, selected: _city);
    if (place == null) return;
    _userPickedCity = true;
    _selectCity(place.city, moveMap: false);
    setState(() =>
        _placeLabel = place.district == null ? null : place.label);
    _mapController.move(place.center, place.zoom);
  }

  void _openAreaById(String id) {
    for (final a in _repo.allLoaded) {
      if (a.id == id) {
        _mapController.move(a.position, 18);
        showAreaDetails(context, a, userPosition: _monitor.position);
        return;
      }
    }
  }

  void _centerOnUser() {
    final pos = _monitor.position;
    if (pos == null) {
      _monitor.requestPermissions();
      return;
    }
    _userPickedCity = false;
    _lastAutoCity = null;
    _mapController.move(pos, 17);
    _onMonitorChanged();
  }

  Future<void> _toggleAlerts() async {
    final enable = !_monitor.alertsEnabled;
    await _monitor.setAlertsEnabled(enable);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enable
          ? 'Benachrichtigungen an: Du wirst im Umkreis von 30 m informiert.'
          : 'Benachrichtigungen aus.'),
    ));
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  List<Marker> _markers(List<SmokingArea> areas) => [
        for (final a in areas)
          Marker(
            key: ValueKey(a.id),
            point: a.position,
            width: 36,
            height: 36,
            child: _AreaMarker(area: a),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // One merged data set for all of Japan – every source, every city.
    final markers = _markersFor(_repo.allVisible);
    final byKey = _markerAreas;
    final userPos = _monitor.position;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _pickCity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(_placeLabel ?? _city.name,
                    overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: _monitor.alertsEnabled
                ? 'Benachrichtigungen ausschalten'
                : 'Benachrichtigungen einschalten',
            icon: Icon(_monitor.alertsEnabled
                ? Icons.notifications_active
                : Icons.notifications_off_outlined),
            onPressed: _toggleAlerts,
          ),
          IconButton(
            tooltip: 'Neu laden',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _loadCity(_city, force: true),
          ),
          IconButton(
            tooltip: 'Info',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _city.center,
              initialZoom: _city.zoom,
              minZoom: 5,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.c0deltin.smoking_areas',
                maxNativeZoom: 19,
              ),
              if (userPos != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: userPos,
                    radius: ProximityMonitor.alertRadiusMeters,
                    useRadiusInMeter: true,
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderColor: theme.colorScheme.primary,
                    borderStrokeWidth: 1.5,
                  ),
                ]),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: markers,
                  maxClusterRadius: 60,
                  disableClusteringAtZoom: 17,
                  size: const Size(42, 42),
                  showPolygon: false,
                  onMarkerTap: (m) {
                    final a = byKey[m.key];
                    if (a != null) {
                      showAreaDetails(context, a, userPosition: userPos);
                    }
                  },
                  builder: (context, markers) => Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${markers.length}',
                      style: TextStyle(
                        color: theme.colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              if (userPos != null)
                MarkerLayer(markers: [
                  Marker(
                    point: userPos,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(blurRadius: 4, color: Colors.black26),
                        ],
                      ),
                    ),
                  ),
                ]),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap-Mitwirkende',
                    onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _StatusBanner(
              data: _data,
              cityCount: _repo.areasIn(_city.bounds).length,
              error: _error,
              loading: _loading,
              monitor: _monitor,
              onRetry: () => _loadCity(_city, force: true),
              onFixPermissions: _monitor.openSettings,
              onNearestTap: (a) =>
                  showAreaDetails(context, a, userPosition: userPos),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Mein Standort',
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Raucherzonen Japan',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.smoking_rooms, size: 40),
      children: [
        const Text(
          'Zeigt öffentliche Raucherbereiche (喫煙所) in allen großen Städten '
          'Japans. In vielen japanischen Städten ist das Rauchen auf der '
          'Straße verboten und nur an ausgewiesenen Stellen erlaubt.\n\n'
          'Ist die Benachrichtigung aktiv, bekommst du eine Push-Mitteilung, '
          'sobald du dich einem Raucherbereich auf 30 m näherst – auch wenn '
          'die App im Hintergrund läuft.\n',
        ),
        const Text('Datenquellen:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final s in _repo.sources)
          Text('• ${s.displayName}: ${s.attribution}'),
        const SizedBox(height: 8),
        const Text(
          'Offizielle Einträge (blau umrandet) stammen aus Listen der Städte '
          'und Bezirke; liegt ein OSM-Eintrag am selben Ort, werden beide zu '
          'einem Marker zusammengeführt. Ohne Koordinaten veröffentlichte '
          'Adressen wurden über die GSI-Adresssuche verortet und sind als '
          '„ungefähr“ gekennzeichnet.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Kartenkacheln: © OpenStreetMap-Mitwirkende.\n'
          'Angaben ohne Gewähr – fehlende oder falsche Einträge kannst du '
          'direkt auf openstreetmap.org korrigieren (amenity=smoking_area).',
        ),
      ],
    );
  }
}

class _AreaMarker extends StatelessWidget {
  const _AreaMarker({required this.area});
  final SmokingArea area;

  @override
  Widget build(BuildContext context) {
    final indoor = area.isIndoor == true;
    return Container(
      decoration: BoxDecoration(
        color: indoor ? Colors.deepPurple : Colors.teal,
        shape: BoxShape.circle,
        // Official entries get a blue ring.
        border: Border.all(
          color: area.isOfficial ? Colors.lightBlueAccent : Colors.white,
          width: area.isOfficial ? 3 : 2,
        ),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black38)],
      ),
      child: const Icon(Icons.smoking_rooms, color: Colors.white, size: 20),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.data,
    required this.cityCount,
    required this.error,
    required this.loading,
    required this.monitor,
    required this.onRetry,
    required this.onFixPermissions,
    required this.onNearestTap,
  });

  final CityAreas? data;
  final int cityCount;
  final String? error;
  final bool loading;
  final ProximityMonitor monitor;
  final VoidCallback onRetry;
  final VoidCallback onFixPermissions;
  final void Function(SmokingArea) onNearestTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget card(Widget child, {Color? color}) => Card(
          color: color,
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: child,
          ),
        );

    if (error != null && data == null) {
      return card(
        Row(children: [
          const Icon(Icons.cloud_off),
          const SizedBox(width: 8),
          const Expanded(child: Text('Daten konnten nicht geladen werden.')),
          TextButton(onPressed: onRetry, child: const Text('Erneut')),
        ]),
        color: theme.colorScheme.errorContainer,
      );
    }

    final state = monitor.locationState;
    if (state == LocationState.denied ||
        state == LocationState.deniedForever ||
        state == LocationState.serviceDisabled) {
      return card(
        Row(children: [
          const Icon(Icons.location_disabled),
          const SizedBox(width: 8),
          Expanded(
            child: Text(state == LocationState.serviceDisabled
                ? 'Standortdienste sind deaktiviert.'
                : 'Ohne Standortzugriff keine 30-m-Benachrichtigung.'),
          ),
          TextButton(
            onPressed: onFixPermissions,
            child: const Text('Einstellungen'),
          ),
        ]),
        color: theme.colorScheme.tertiaryContainer,
      );
    }

    final nearest = monitor.nearest();
    final int? count = cityCount == 0 && loading ? null : cityCount;
    return card(
      InkWell(
        onTap: nearest == null ? null : () => onNearestTap(nearest.area),
        child: Row(children: [
          Icon(
            monitor.alertsEnabled
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nearest == null
                      ? (count == null
                          ? 'Lade Raucherbereiche …'
                          : '$count Raucherbereiche in dieser Stadt')
                      : 'Nächster: ${nearest.area.title}',
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nearest != null)
                  Text(
                    '${formatDistance(nearest.distanceMeters)} entfernt'
                    '${count != null ? ' · $count in dieser Stadt' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (state == LocationState.whileInUse && monitor.alertsEnabled)
                  Text(
                    'Tipp: „Immer“ erlauben für Hinweise im Hintergrund.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (nearest != null) const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}
