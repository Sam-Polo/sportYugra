// main:
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;
import 'dart:developer' as developer;
import 'scenes/map_screen.dart'; // Import the MapScreen from map_screen.dart
import 'package:flutter_dotenv/flutter_dotenv.dart'; // импортируем пакет для работы с .env
// Импорт экрана спортивных объектов
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем переменные окружения из .env файла
  await dotenv.load(fileName: ".env");
  developer.log('Loaded .env file');

  // Инициализация Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Initialized Firebase');
  } catch (e) {
    developer.log('Error initializing Firebase: $e');
  }

  // Инициализация Yandex MapKit с ключом из .env
  final String yandexApiKey = dotenv.env['YANDEX_MAPKIT_API_KEY']!;
  init.initMapkit(apiKey: yandexApiKey);
  developer.log('Initialized MapKit');

  // Запрашиваем разрешение на геолокацию и ждем его перед запуском приложения
  final isLocationPermissionGranted = await requestLocationPermission();
  developer.log('Location permission granted: $isLocationPermissionGranted');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const MapScreen(),
      },
      initialRoute: '/',
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
