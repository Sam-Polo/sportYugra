// map screen:
import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart' show rootBundle;
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/image.dart';
import 'dart:developer' as dev;
import '../data/placemarks.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends fm.StatefulWidget {
  const MapScreen({super.key});

  @override
  fm.State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends fm.State<MapScreen>
    with fm.WidgetsBindingObserver {
  MapWindow? _mapWindow;
  String? _mapStyle;
  UserLocationLayer? _userLocationLayer;

  @override
  void initState() {
    super.initState();
    fm.WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _requestLocationPermission();
    print('MapKit onStart');
    mapkit.onStart();
  }

  @override
  void dispose() {
    fm.WidgetsBinding.instance.removeObserver(this);
    print('MapKit onStop');
    mapkit.onStop();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
      dev.log('Map style loaded');
      if (_mapWindow != null) {
        _mapWindow?.map.setMapStyle(_mapStyle!);
        dev.log('Map style applied');
      }
    } catch (e) {
      dev.log('Error loading map style: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      print('[log] Location permission granted');
      // Инициализируем слой геолокации только после получения разрешения
      if (_mapWindow != null) {
        await _initUserLocation();
      }
    } else {
      print('[log] Location permission denied');
    }
  }

  Future<void> _initUserLocation() async {
    if (_mapWindow == null) return;

    try {
      final locationLayer = await mapkit.createUserLocationLayer(_mapWindow!);
      setState(() {
        _userLocationLayer = locationLayer;
      });

      // Включаем отображение местоположения пользователя
      _userLocationLayer?.setVisible(true);

      dev.log('User location layer initialized');
    } catch (e) {
      dev.log('Error initializing user location: $e');
    }
  }

  void _moveToUserLocation() {
    if (_userLocationLayer == null) {
      _initUserLocation();
      return;
    }

    try {
      final position = _userLocationLayer?.cameraPosition();
      if (position != null) {
        final cameraCallback = MapCameraCallback(onMoveFinished: (isFinished) {
          if (isFinished) {
            dev.log('Camera movement completed');
          } else {
            dev.log('Camera movement interrupted');
          }
        });

        _mapWindow?.map.moveWithAnimation(
          position,
          const Animation(AnimationType.Linear, duration: 1.0),
          cameraCallback: cameraCallback,
        );
        dev.log('Moving to user location');
      } else {
        dev.log('User location is not available');
      }
    } catch (e) {
      dev.log('Error moving to user location: $e');
    }
  }

  void _addPlacemarks() {
    if (_mapWindow == null) return;

    for (final placemark in placemarks) {
      final mapPlacemark = _mapWindow!.map.mapObjects.addPlacemark()
        ..geometry = placemark.location
        ..setText(placemark.name)
        ..setTextStyle(
          const TextStyle(
            size: 12.0,
            color: fm.Colors.black,
            outlineColor: fm.Colors.white,
            placement: TextStylePlacement.Right,
            offset: 5.0,
          ),
        )
        ..setIcon(
          ImageProvider.fromImageProvider(
            const fm.AssetImage("assets/images/Yandex_Maps_icon.png"),
          ),
        )
        ..setIconStyle(
          const IconStyle(
            scale: 0.1,
          ),
        );
    }
  }

  void _logUserLocation() {
    if (_userLocationLayer == null) {
      dev.log('User location layer is not initialized');
      return;
    }
    final position = _userLocationLayer?.cameraPosition();
    if (position != null) {
      dev.log(
          'User location: lat: ${position.target.latitude} long: ${position.target.longitude}');
    } else {
      dev.log('User location is not available');
    }
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
      body: fm.Stack(
        children: [
          YandexMap(
            onMapCreated: (mapWindow) {
              print('Map created: $mapWindow');
              _mapWindow = mapWindow;

              if (_mapStyle != null) {
                _mapWindow?.map.setMapStyle(_mapStyle!);
                print('Map style applied');
              }

              try {
                _mapWindow?.map.move(
                  CameraPosition(
                    Point(latitude: 60.988094, longitude: 69.037551),
                    zoom: 12.7,
                    azimuth: 0.0,
                    tilt: 17.0,
                  ),
                );
                print('Camera placed');

                // Инициализируем слой местоположения только если есть разрешение
                Permission.location.isGranted.then((isGranted) {
                  if (isGranted) {
                    _initUserLocation();
                  }
                });

                // Добавляем метки после инициализации карты
                _addPlacemarks();
              } catch (e) {
                print('Error moving camera: $e');
              }
            },
          ),
          fm.Positioned(
            right: 16,
            bottom: 16,
            child: fm.Material(
              color: fm.Colors.black,
              borderRadius: fm.BorderRadius.circular(8),
              elevation: 4,
              child: fm.InkWell(
                borderRadius: fm.BorderRadius.circular(8),
                onTap: _logUserLocation,
                child: fm.Container(
                  width: 48,
                  height: 48,
                  child: fm.Center(
                    child: fm.Text(
                      "Я",
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 24,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
