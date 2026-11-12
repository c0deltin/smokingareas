import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:url_launcher/url_launcher.dart';

import 'package:latlong2/latlong.dart';

import '../community/community_service.dart';
import '../community/local_migration.dart';
import '../data/cities.dart';
import '../models/city.dart';
import '../models/smoking_area.dart';
import '../services/map_clustering.dart';
import '../services/notification_service.dart';
import '../services/proximity_monitor.dart';
import '../services/smoking_area_repository.dart';
import '../services/snapshot_updater.dart';
import '../sources/official_opendata_source.dart';
import 'area_details_sheet.dart';
import 'city_picker.dart';
import 'legend_sheet.dart';
import 'local_data_sheet.dart';
import 'marker_icons.dart';
import 'profile_sheet.dart';
import 'report_spot_sheet.dart';
import 'settings_sheet.dart';
import 'sign_in_sheet.dart';
import 'spot_style.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.repository,
    required this.monitor,
    required this.community,
    this.updater,
    this.localMigration,
  });

  final SmokingAreaRepository repository;
  final ProximityMonitor monitor;
  final CommunityService community;

  /// Data updates without an app release (null in tests).
  final DataUpdater? updater;

  /// Device-only data of earlier versions, offered for upload after sign-in.
  final LocalDataMigration? localMigration;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

LatLng _ll(gm.LatLng p) => LatLng(p.latitude, p.longitude);
gm.LatLng _gm(LatLng p) => gm.LatLng(p.latitude, p.longitude);

class _MapScreenState extends State<MapScreen> {
  gm.GoogleMapController? _map;
  late gm.CameraPosition _camera =
      gm.CameraPosition(target: _gm(_city.center), zoom: _city.zoom);
  GeoBounds? _visibleRegion;
  MarkerIcons? _icons;
  List<MapCluster> _clusters = const [];
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
  CommunityService get _community => widget.community;

  /// "Spot melden": the user moves the map until the cross hair is on the
  /// smoking area and confirms.
  SpotCategory? _reportCategory;
  bool get _reportMode => _reportCategory != null;

  /// Categories shown on the map (both by default).
  final Set<SpotCategory> _visible = {...SpotCategory.values};

  @override
  void initState() {
    super.initState();
    _monitor.addListener(_onMonitorChanged);
    _monitor.heading?.addListener(_onHeadingChanged);
    _repo.addListener(_onRepoChanged);
    _community.addListener(_onCommunityChanged);
    NotificationService.instance.onTap = _openAreaById;
    _loadCity(_city);
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissions());
  }

  @override
  void dispose() {
    _monitor.removeListener(_onMonitorChanged);
    _monitor.heading?.removeListener(_onHeadingChanged);
    _repo.removeListener(_onRepoChanged);
    _community.removeListener(_onCommunityChanged);
    NotificationService.instance.onTap = null;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_icons == null) {
      final icons = MarkerIcons(MediaQuery.devicePixelRatioOf(context));
      _icons = icons;
      icons.prepareBase().then((_) => _updateClusters());
    }
  }

  /// After signing in: offer to upload device-only data (once).
  void _onCommunityChanged() {
    if (_community.isSignedIn && mounted) {
      maybeOfferLocalUpload(context, _community, widget.localMigration);
    }
  }

  /// New data from any source/city: redraw the (single, merged) map.
  void _onRepoChanged() => _updateClusters();

  /// Redraw the location cone only for noticeable turns (the map diffs all
  /// markers on every rebuild).
  double? _drawnHeading;
  void _onHeadingChanged() {
    final h = _monitor.heading?.heading;
    final old = _drawnHeading;
    if (h == null && old == null) return;
    if (h != null && old != null) {
      final diff = ((h - old + 540) % 360 - 180).abs();
      if (diff < 3) return;
    }
    _drawnHeading = h;
    final spread = _monitor.heading?.spread;
    if (h != null && spread != null && _icons?.cone(spread) == null) {
      _icons?.ensureCone(spread).then((_) {
        if (mounted) setState(() {});
      });
    }
    if (mounted) setState(() {});
  }

  void _moveTo(LatLng position, double zoom) {
    _camera = gm.CameraPosition(target: _gm(position), zoom: zoom);
    _map?.animateCamera(gm.CameraUpdate.newLatLngZoom(_gm(position), zoom));
  }

  Future<void> _onCameraIdle() async {
    final map = _map;
    if (map == null) return;
    final r = await map.getVisibleRegion();
    _visibleRegion = GeoBounds(
      south: r.southwest.latitude,
      west: r.southwest.longitude,
      north: r.northeast.latitude,
      east: r.northeast.longitude,
    );
    await _updateClusters();
  }

  /// One merged data set for all of Japan – every source, every city –
  /// clustered for the visible part of the map.
  Future<void> _updateClusters() async {
    final icons = _icons;
    final region = _visibleRegion;
    if (icons == null || region == null || !mounted) {
      if (mounted) setState(() {});
      return;
    }
    final clusters = clusterAreas(
      _repo.allVisible.where((a) => _visible.contains(a.category)),
      visible: region,
      zoom: _camera.zoom,
    );
    await Future.wait([
      for (final c in clusters)
        if (c.isSingle)
          icons.ensureSpot(SpotMarker.fromArea(c.areas.single))
        else
          icons.ensureCluster(c.category, ClusterBubble.label(c.areas.length)),
    ]);
    if (!mounted) return;
    setState(() => _clusters = clusters);
  }

  void _onClusterTap(MapCluster c) {
    if (c.isSingle) {
      showAreaDetails(context, c.areas.single,
          userPosition: _monitor.position, community: _community);
      return;
    }
    final b = c.bounds;
    final tiny = b.north - b.south < 0.0002 && b.east - b.west < 0.0002;
    if (tiny) {
      _moveTo(c.center, math.max(_camera.zoom + 2, 17));
      return;
    }
    _map?.animateCamera(gm.CameraUpdate.newLatLngBounds(
      gm.LatLngBounds(
        southwest: gm.LatLng(b.south, b.west),
        northeast: gm.LatLng(b.north, b.east),
      ),
      64,
    ));
  }

  Set<gm.Marker> _mapMarkers() {
    final icons = _icons;
    if (icons == null) return const {};
    final markers = <gm.Marker>{};
    for (final c in _clusters) {
      final icon = c.isSingle
          ? icons.spot(SpotMarker.fromArea(c.areas.single))
          : icons.cluster(c.category, ClusterBubble.label(c.areas.length));
      if (icon == null) continue;
      markers.add(gm.Marker(
        markerId: gm.MarkerId(c.id),
        position: _gm(c.center),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        consumeTapEvents: true,
        zIndexInt: c.isSingle ? 1 : 2,
        onTap: () => _onClusterTap(c),
      ));
    }
    final pos = _monitor.position;
    if (pos != null) {
      final service = _monitor.heading;
      final heading = service?.heading;
      final cone = service == null ? null : icons.cone(service.spread);
      if (heading != null && cone != null) {
        markers.add(gm.Marker(
          markerId: const gm.MarkerId('me:cone'),
          position: _gm(pos),
          icon: cone,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: heading,
          zIndexInt: 10,
          consumeTapEvents: true,
        ));
      }
      final dot = icons.dot;
      if (dot != null) {
        markers.add(gm.Marker(
          markerId: const gm.MarkerId('me:dot'),
          position: _gm(pos),
          icon: dot,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 11,
          consumeTapEvents: true,
        ));
      }
    }
    return markers;
  }

  Future<void> _askPermissions() async {
    if (_monitor.locationState != LocationState.always) {
      await _monitor.requestPermissions();
    }
    // Once after installation: sign in or stay anonymous.
    if (mounted) await maybeShowInitialSignIn(context, _community);
    if (mounted) {
      await maybeOfferLocalUpload(context, _community, widget.localMigration);
    }
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
        _moveTo(pos, 16);
      }
    }
    if (mounted) setState(() {});
  }

  /// "Reload": live data of the current city plus newer official data.
  Future<void> _reload() async {
    final updater = widget.updater;
    final cityLoad = _loadCity(_city, force: true);
    unawaited(_community.refresh());
    if (updater != null) {
      final result = await updater.check(force: true);
      if (result.updated) {
        await _repo.reloadBundled();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Map data updated (${result.version}).'),
          ));
        }
      }
    }
    await cityLoad;
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
              ? 'Offline – showing saved data from '
                  '${_formatDate(data.fetchedAt)}.'
              : 'Some sources are unreachable.'),
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
    if (moveMap) _moveTo(city.center, city.zoom);
    _loadCity(city);
  }

  Future<void> _pickCity() async {
    final place = await showCityPicker(context, selected: _city);
    if (place == null) return;
    _userPickedCity = true;
    _selectCity(place.city, moveMap: false);
    setState(() =>
        _placeLabel = place.district == null ? null : place.label);
    _moveTo(place.center, place.zoom);
  }

  void _openAreaById(String id) {
    for (final a in _repo.allLoaded) {
      if (a.id == id) {
        _moveTo(a.position, 18);
        showAreaDetails(context, a,
            userPosition: _monitor.position, community: _community);
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
    _moveTo(pos, 17);
    _onMonitorChanged();
  }

  Future<void> _toggleAlerts() async {
    final enable = !_monitor.alertsEnabled;
    await _monitor.setAlertsEnabled(enable);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enable
          ? 'Alerts on: you will be notified within ${_monitor.alertRadius.round()} m.'
          : 'Alerts off.'),
    ));
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                ? 'Turn alerts off'
                : 'Turn alerts on',
            icon: Icon(_monitor.alertsEnabled
                ? Icons.notifications_active
                : Icons.notifications_off_outlined),
            onPressed: _toggleAlerts,
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload,
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) => switch (v) {
              'legend' => showLegendSheet(context),
              'settings' => showSettingsSheet(context, _monitor, _community),
              'profile' => showProfileSheet(context, _community),
              _ => _showInfo(context),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'legend',
                child: ListTile(
                  leading: Icon(Icons.legend_toggle),
                  title: Text('Legend'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.account_circle_outlined),
                  title: Text('Profile'),
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Info'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          gm.GoogleMap(
            initialCameraPosition: _camera,
            minMaxZoomPreference: const gm.MinMaxZoomPreference(5, 20),
            // Own location symbol (dot + direction cone) and own buttons.
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Room for the data attribution below the Google logo.
            padding: const EdgeInsets.only(bottom: 18),
            onMapCreated: (c) {
              _map = c;
              c.moveCamera(gm.CameraUpdate.newCameraPosition(_camera));
            },
            onCameraMove: (p) => _camera = p,
            onCameraIdle: _onCameraIdle,
            markers: _mapMarkers(),
            circles: {
              if (userPos != null)
                gm.Circle(
                  circleId: const gm.CircleId('alert-radius'),
                  center: _gm(userPos),
                  radius: _monitor.alertRadius,
                  fillColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                  strokeColor: theme.colorScheme.primary,
                  strokeWidth: 2,
                ),
            },
          ),
          Positioned(
            left: 8,
            bottom: 2,
            child: GestureDetector(
              onTap: () =>
                  launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              child: Text(
                'Data © OpenStreetMap contributors',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.black87,
                  backgroundColor: Colors.white70,
                ),
              ),
            ),
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
            child: Column(children: [
            _StatusBanner(
              data: _data,
              cityCount: _repo
                  .areasIn(_city.bounds)
                  .where((a) => a.category == SpotCategory.smoking)
                  .length,
              error: _error,
              loading: _loading,
              monitor: _monitor,
              onRetry: () => _loadCity(_city, force: true),
              onFixPermissions: _monitor.openSettings,
              onNearestTap: (a) =>
                  showAreaDetails(context, a,
                      userPosition: userPos, community: _community),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, children: [
                for (final c in SpotCategory.values)
                  FilterChip(
                    avatar: Icon(
                      categoryIcon(c),
                      size: 18,
                      color: categoryColor(c),
                    ),
                    label: Text(c.pluralLabel),
                    selected: _visible.contains(c),
                    showCheckmark: false,
                    backgroundColor: theme.colorScheme.surface,
                    selectedColor:
                        categoryColor(c).withValues(alpha: 0.22),
                    side: BorderSide(color: categoryColor(c)),
                    onSelected: (on) {
                      setState(() {
                        on ? _visible.add(c) : _visible.remove(c);
                      });
                      _updateClusters();
                    },
                  ),
              ]),
            ),
            ]),
          ),
          if (_reportMode) ..._reportOverlay(theme),
        ],
      ),
      floatingActionButton: _reportMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'report',
                  tooltip: 'Report a spot',
                  onPressed: _startReport,
                  child: const Icon(Icons.add_location_alt_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'locate',
                  tooltip: 'My location',
                  onPressed: _centerOnUser,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------
  // Report a new spot
  // ---------------------------------------------------------------------

  Future<void> _startReport() async {
    if (!await ensureSignedIn(context, _community,
            reason: 'Sign in to report new places.') ||
        !mounted) {
      return;
    }
    final category = await askSpotCategory(context);
    if (category == null || !mounted) return;
    _visible.add(category);
    _updateClusters();
    final pos = _monitor.position;
    if (pos != null) {
      _moveTo(pos, 18);
    } else if (_camera.zoom < 16) {
      _moveTo(_ll(_camera.target), 17);
    }
    setState(() => _reportCategory = category);
  }

  List<Widget> _reportOverlay(ThemeData theme) => [
        // Cross hair in the middle of the map.
        IgnorePointer(
          child: Center(
            child: Icon(Icons.add, size: 44, color: theme.colorScheme.error),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 24,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  'Report ${_reportCategory!.label.toLowerCase()}: move the map '
                  'until the cross is exactly on the spot.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _reportCategory = null),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmReportPosition,
                      child: const Text('Report here'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ];

  Future<void> _confirmReportPosition() async {
    final position = _ll(_camera.target);
    final category = _reportCategory!;

    // Avoid duplicates: offer the existing spot instead.
    const distance = Distance();
    SmokingArea? nearest;
    var nearestDist = double.infinity;
    for (final a in _repo.allVisible) {
      if (a.category != category) continue;
      if ((a.latitude - position.latitude).abs() > 0.0005) continue;
      final d = distance(position, a.position);
      if (d < nearestDist) {
        nearest = a;
        nearestDist = d;
      }
    }
    // Same radius as the merge of reports, so the user decides here.
    Set<String> notSameAs = const {};
    if (nearest != null &&
        nearestDist <= SmokingAreaRepository.mergeRadiusCommunity) {
      final existing = nearest;
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already on the map?'),
          content: Text('"${existing.title}" is ${nearestDist.round()} m away. '
              'Is it the same place?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, report new'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, show it'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice) {
        setState(() => _reportCategory = null);
        showAreaDetails(context, existing,
            userPosition: _monitor.position, community: _community);
        return;
      }
      notSameAs = existing.allIds;
    }

    if (!mounted) return;
    final input = await showReportSpotSheet(context, category);
    if (!mounted || input == null) return;
    var photoFailed = false;
    final saved = await contribute(
        context,
        _community,
        () => withProgress(context, () async {
              try {
                await _community.reportSpot(
      position: position,
      name: input.name,
      description: input.description,
      indoor: input.indoor,
      covered: input.covered,
      publicAccess: input.publicAccess,
      accessNote: input.accessNote,
      category: input.category,
      wheelchair: input.wheelchair,
      changingTable: input.changingTable,
      photo: input.photo,
      notSameAs: notSameAs,
                );
              } on PhotoUploadFailed {
                photoFailed = true;
              }
            }));
    if (!mounted || !saved) return;
    setState(() => _reportCategory = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(photoFailed
          ? 'Your spot is on the map, but the photo could not be uploaded – '
              'add it again from the spot.'
          : 'Thanks! Your spot is now on the map.'),
    ));
  }

  void _showInfo(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'smokingareas',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.smoking_rooms, size: 40),
      children: [
        const Text(
          'Shows public smoking areas (喫煙所, green) and public toilets '
          '(公衆トイレ, blue) in all major Japanese cities. Many Japanese '
          'cities ban smoking on the street and only allow it in designated '
          'areas.\n\n'
          'With alerts on you get a notification as soon as you come close '
          'to a smoking area (radius configurable in Settings) – also while '
          'the app runs in the background (not for toilets).\n',
        ),
        const Text('Data sources:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final s in _repo.sources)
          Text('• ${s.displayName}: ${s.attribution}'),
        for (final s in _repo.sources.whereType<OfficialOpenDataSource>())
          FutureBuilder<String>(
            future: s.version(),
            builder: (context, snap) => snap.hasData
                ? Text('Official data version: ${snap.data} – updated '
                    'automatically, also via Reload.')
                : const SizedBox.shrink(),
          ),
        const SizedBox(height: 8),
        const Text(
          'The legend (menu ⋮) explains all symbols. Official entries (gold '
          'ring) come from lists published by cities and wards; if an OSM '
          'entry is at the same place, both are merged into one marker. '
          'Addresses published without coordinates were located with the GSI '
          'address search and are marked as "approximate".',
        ),
        const SizedBox(height: 8),
        const Text(
          'Map: Google Maps. Spot data from OpenStreetMap: © OpenStreetMap '
          'contributors (ODbL).\n'
          'No guarantee of accuracy – you can fix missing or wrong entries '
          'directly on openstreetmap.org (amenity=smoking_area, '
          'amenity=toilets).',
        ),
        const SizedBox(height: 8),
        const LegalLinks(),
      ],
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
          const Expanded(child: Text('Could not load data.')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
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
                ? 'Location services are turned off.'
                : 'Without location access there are no proximity alerts.'),
          ),
          TextButton(
            onPressed: onFixPermissions,
            child: const Text('Settings'),
          ),
        ]),
        color: theme.colorScheme.tertiaryContainer,
      );
    }

    final nearest = monitor.nearest();
    final nearestToilet = monitor.nearest(SpotCategory.toilet);
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
                          ? 'Loading smoking areas …'
                          : '$count smoking areas in this city')
                      : 'Nearest: ${nearest.area.title}',
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nearest != null)
                  Text(
                    '${formatDistance(nearest.distanceMeters)} away'
                    '${count != null ? ' · $count in this city' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (nearestToilet != null)
                  InkWell(
                    onTap: () => onNearestTap(nearestToilet.area),
                    child: Row(children: [
                      Icon(Icons.wc,
                          size: 14, color: categoryColor(SpotCategory.toilet)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Toilet: ${nearestToilet.area.title} · '
                          '${formatDistance(nearestToilet.distanceMeters)}',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                if (state == LocationState.whileInUse && monitor.alertsEnabled)
                  Text(
                    'Tip: allow "Always" for alerts in the background.',
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
