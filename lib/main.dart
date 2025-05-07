// main:
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;
import 'scenes/map_screen.dart'; // Import the MapScreen from map_screen.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Initializing MapKit...');
    init.initMapkit(apiKey: 'b9296eef-e8fc-4109-b187-d45172699d10');
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
      home: const MapScreen(), // Используем MapScreen из map_screen.dart
    );
  }
}
