import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;
import 'scenes/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Initializing MapKit...');
    init.initMapkit(apiKey: '.....5172699d10');
    print('MapKit initialized');
  } catch (e) {
    print('MapKit initialization failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MapScreen(),
    );
  }
}
