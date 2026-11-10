import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import 'community/auth_service.dart';
import 'community/community_backend.dart';
import 'community/community_service.dart';
import 'community/photo_storage.dart';
import 'services/proximity_monitor.dart';
import 'services/smoking_area_repository.dart';
import 'ui/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SmokingAreaRepository();
  // Official data for all of Japan + everything cached on the device: shown
  // on the very first frame, before any network request.
  await repository.warmUp();

  // Community features – local adapters for now (no server yet).
  final backend = LocalCommunityBackend(getApplicationSupportDirectory);
  final auth = LocalAuthService(backend);
  await auth.init();
  final community = CommunityService(
    backend: backend,
    photos: LocalPhotoStorage(getApplicationSupportDirectory),
    auth: auth,
  );
  await community.init();
  void syncCommunity() => repository.setCommunity(
        spots: community.spotsAsAreas,
        isHidden: community.isHidden,
      );
  community.addListener(syncCommunity);
  syncCommunity();
  final monitor = ProximityMonitor(repository: repository);
  await monitor.init();
  runApp(SmokingAreasApp(
    repository: repository,
    monitor: monitor,
    community: community,
  ));
}

class SmokingAreasApp extends StatelessWidget {
  const SmokingAreasApp({
    super.key,
    required this.repository,
    required this.monitor,
    required this.community,
  });

  final SmokingAreaRepository repository;
  final ProximityMonitor monitor;
  final CommunityService community;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.teal;
    return MaterialApp(
      title: 'Raucherzonen Japan',
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
      ),
    );
  }
}
