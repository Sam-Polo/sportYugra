// main:
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;
import 'dart:developer' as developer;
import 'scenes/map_screen.dart'; // Import the MapScreen from map_screen.dart
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    developer.log('Initializing MapKit...');
    init.initMapkit(apiKey: 'b9296eef-e8fc-4109-b187-d45172699d10');
    developer.log('MapKit initialized');
  } catch (e) {
    developer.log('MapKit initialization failed: $e');
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

Future<bool> requestLocationPermission() async {
  // Проверяем текущий статус разрешения
  var status = await Permission.location.status;

  // Если разрешение уже предоставлено
  if (status.isGranted) {
    return true;
  }

  // Если разрешение отклонено навсегда
  if (status.isPermanentlyDenied) {
    // Можно показать диалог с объяснением и предложением открыть настройки
    return false;
  }

  // Запрашиваем разрешение
  status = await Permission.location.request();
  return status.isGranted;
}
