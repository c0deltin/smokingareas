import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community/auth_service.dart';
import 'community/community_backend.dart';
import 'community/community_service.dart';
import 'community/local_migration.dart';
import 'community/outbox.dart';
import 'community/photo_storage.dart';
import 'community/server_backend.dart';
import 'services/heading_service.dart';
import 'services/osm_tiles.dart';
import 'services/proximity_monitor.dart';
import 'services/smoking_area_repository.dart';
import 'services/snapshot_updater.dart';
import 'sources/official_opendata_source.dart';
import 'sources/osm_snapshot_source.dart';
import 'sources/overpass_source.dart';
import 'ui/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Official data: the bundled snapshot, or a newer one downloaded by the
  // SnapshotUpdater (data updates without an app release).
  final snapshots = SnapshotStore(getApplicationSupportDirectory);
  final official = OfficialOpenDataSource(
    loader: snapshots.preferNewer(() =>
        rootBundle.loadString('assets/opendata/official_smoking_areas.json')),
  );
  // OpenStreetMap: all of Japan in tiles (weekly export, bundled and
  // updated like the official data). Until the tiles are installed, the
  // older city-only export; live Overpass queries only without either.
  final tiles = OsmTileStore(getApplicationSupportDirectory);
  final osmStore = SnapshotStore(getApplicationSupportDirectory,
      fileName: 'osm_snapshot.json', metaName: 'osm-meta.json');
  final osm = OsmSnapshotSource(osmStore.preferNewer(() =>
      rootBundle.loadString('assets/opendata/osm_spots.json')));
  late final SmokingAreaRepository repository;
  repository = SmokingAreaRepository(
    sources: [
      official,
      osm,
      OverpassSource(
          isFallbackActive: () => !osm.hasData && !repository.usesTiles),
    ],
    tiles: tiles,
  );
  final updater = DataUpdaters([
    SnapshotUpdater(store: snapshots, source: official),
    SnapshotUpdater(store: osmStore, source: osm),
    OsmTileUpdater(store: tiles, onUpdated: repository.reloadTiles),
  ]);
  // Splitting the bundled tiles takes a moment on the first start: in the
  // background, the city-only data is shown meanwhile.
  unawaited(installBundledTiles(tiles, () async {
    try {
      final data = await rootBundle.load('assets/opendata/osm_tiles.txt.gz');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }).then((installed) async {
    if (installed) await repository.reloadTiles();
  }));
  // Official data for all of Japan + everything cached on the device: shown
  // on the very first frame, before any network request.
  await repository.warmUp();

  // Community features: the server when configured at build time, else
  // local adapters (development).
  final CommunityService community;
  LocalDataMigration? localMigration;
  if (ServerConfig.isConfigured) {
    await Supabase.initialize(
        url: ServerConfig.url, publishableKey: ServerConfig.anonKey);
    final client = Supabase.instance.client;
    final auth = ServerAuthService(client);
    await auth.init();
    community = CommunityService(
      backend: ServerCommunityBackend(client),
      photos: ServerPhotoStorage(client, getApplicationCacheDirectory),
      auth: auth,
      // Contributions without a connection wait here and are sent later.
      outbox: Outbox(getApplicationSupportDirectory),
    );
    // Network: do not delay the first frame.
    unawaited(community.init());
    // Data earlier versions kept only on this device.
    localMigration = LocalDataMigration(
      local: LocalCommunityBackend(getApplicationSupportDirectory),
      localPhotos: LocalPhotoStorage(getApplicationSupportDirectory),
      photosDirectory: () async => Directory(
          '${(await getApplicationSupportDirectory()).path}/community/photos'),
    );
  } else {
    final backend = LocalCommunityBackend(getApplicationSupportDirectory);
    final auth = LocalAuthService(backend);
    await auth.init();
    community = CommunityService(
      backend: backend,
      photos: LocalPhotoStorage(getApplicationSupportDirectory),
      auth: auth,
    );
    await community.init();
  }
  void syncCommunity() => repository.setCommunity(
        spots: community.spotsAsAreas,
        isHidden: community.isHidden,
        annotate: community.annotate,
      );
  community.addListener(syncCommunity);
  syncCommunity();
  final heading = HeadingService()..start();
  final monitor = ProximityMonitor(repository: repository, heading: heading);
  await monitor.init();
  runApp(SmokingAreasApp(
    repository: repository,
    monitor: monitor,
    community: community,
    updater: updater,
    localMigration: localMigration,
  ));

  // At most once a day, in the background: newer official data?
  unawaited(updater.check().then((r) async {
    if (r.updated) await repository.reloadBundled();
  }));
}

class SmokingAreasApp extends StatelessWidget {
  const SmokingAreasApp({
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
  final DataUpdater? updater;
  final LocalDataMigration? localMigration;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2563EB); // app icon blue
    return MaterialApp(
      title: 'Ippuku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: MapScreen(
        repository: repository,
        monitor: monitor,
        community: community,
        updater: updater,
        localMigration: localMigration,
      ),
    );
  }
}
