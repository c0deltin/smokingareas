import 'package:flutter/material.dart';

import 'services/proximity_monitor.dart';
import 'services/smoking_area_repository.dart';
import 'ui/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SmokingAreaRepository();
  // Official data for all of Japan + everything cached on the device: shown
  // on the very first frame, before any network request.
  await repository.warmUp();
  final monitor = ProximityMonitor(repository: repository);
  await monitor.init();
  runApp(SmokingAreasApp(repository: repository, monitor: monitor));
}

class SmokingAreasApp extends StatelessWidget {
  const SmokingAreasApp({
    super.key,
    required this.repository,
    required this.monitor,
  });

  final SmokingAreaRepository repository;
  final ProximityMonitor monitor;

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
      home: MapScreen(repository: repository, monitor: monitor),
    );
  }
}
