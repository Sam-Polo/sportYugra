import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/image.dart';
import '../camera/camera_manager.dart';
import '../permissions/permission_manager.dart';
import '../widgets/map_control_button.dart';

class MapScreen extends fm.StatefulWidget {
  const MapScreen({super.key});

  @override
  fm.State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends fm.State<MapScreen>
    with fm.WidgetsBindingObserver
    implements UserLocationObjectListener {
  MapWindow? _mapWindow;
  String? _mapStyle;
  UserLocationLayer? _userLocationLayer;
  LocationManager? _locationManager;
  CameraManager? _cameraManager;
  late final _permissionManager = const PermissionManager();

  @override
  void initState() {
    super.initState();
    fm.WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _requestLocationPermission();
    dev.log('MapKit onStart');
    mapkit.onStart();
  }

  @override
  void dispose() {
    fm.WidgetsBinding.instance.removeObserver(this);
    _cameraManager?.dispose();
    dev.log('MapKit onStop');
    mapkit.onStop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(fm.AppLifecycleState state) {
    if (state == fm.AppLifecycleState.resumed) {
      _requestLocationPermission();
    }
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
    final permissions = [PermissionType.accessLocation];
    await _permissionManager.tryToRequest(permissions);
    await _permissionManager.showRequestDialog(permissions);

    final status = await Permission.location.status;

    if (status.isGranted && _mapWindow != null && _locationManager != null) {
      dev.log(
          'Location permission granted, attempting to update location/camera');
      _cameraManager?.moveCameraToUserLocation();
    }
  }

  void _initUserLocation() {
    if (_mapWindow == null) return;

    Permission.location.isGranted.then((isGranted) {
      if (isGranted) {
        _userLocationLayer = mapkit.createUserLocationLayer(_mapWindow!)
          ..headingEnabled = true
          ..setVisible(true)
          ..setObjectListener(this);
        dev.log('UserLocationLayer initialized and listener set');

        _locationManager = mapkit.createLocationManager();
        _cameraManager = CameraManager(_mapWindow!, _locationManager!)..start();
        dev.log('LocationManager and CameraManager initialized');
      } else {
        dev.log(
            'Location permission not granted, skipping LocationManager and UserLocationLayer initialization');
      }
    });
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
      appBar: fm.AppBar(
        title: const fm.Text('SportYugra'),
        actions: [
          fm.IconButton(
            icon: const fm.Icon(fm.Icons.list),
            tooltip: 'Спортивные объекты',
            onPressed: () {
              fm.Navigator.pushNamed(context, '/sport_objects');
            },
          ),
        ],
      ),
      body: fm.Stack(
        children: [
          YandexMap(
            onMapCreated: (mapWindow) {
              _mapWindow = mapWindow;

              if (_mapStyle != null) {
                _mapWindow?.map.setMapStyle(_mapStyle!);
              }

              _mapWindow?.map.move(
                CameraPosition(
                  Point(latitude: 60.988094, longitude: 69.037551),
                  zoom: 12.7,
                  azimuth: 0.0,
                  tilt: 17.0,
                ),
              );

              _initUserLocation();
            },
          ),
          // Кнопки зума
          fm.Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: fm.Align(
              alignment: fm.Alignment.centerRight,
              child: fm.Column(
                mainAxisSize:
                    fm.MainAxisSize.min, // Колонку по размеру содержимого
                children: [
                  MapControlButton(
                    icon: fm.Icons.add,
                    backgroundColor: fm.Colors.black,
                    iconColor: fm.Colors.white,
                    onPressed: _zoomIn,
                  ),
                  fm.SizedBox(height: 8), // Небольшой отступ между кнопками
                  MapControlButton(
                    icon: fm.Icons.remove,
                    backgroundColor: fm.Colors.black,
                    iconColor: fm.Colors.white,
                    onPressed: _zoomOut,
                  ),
                  fm.SizedBox(
                      height:
                          8), // Отступ между кнопками зума и кнопкой местоположения
                  MapControlButton(
                    icon: fm.Icons.my_location_outlined,
                    backgroundColor: fm.Colors.black,
                    iconColor: fm.Colors.white,
                    onPressed: () {
                      _cameraManager?.moveCameraToUserLocation();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void onObjectAdded(UserLocationView view) {
    dev.log('onObjectAdded called');
    view.arrow.setIcon(
      ImageProvider.fromImageProvider(
        const fm.AssetImage('assets/images/user_arrow_icon.png'),
      ),
    );
    view.arrow.setIconStyle(
      const IconStyle(
        anchor: math.Point(0.5, 0.5),
        rotationType: RotationType.Rotate,
        zIndex: 0.0,
        scale: 0.2,
      ),
    );
    final pinIcon = view.pin.useCompositeIcon();
    pinIcon.setIcon(
      ImageProvider.fromImageProvider(
          const fm.AssetImage('assets/images/my_location_icon.png')),
      const IconStyle(
        anchor: math.Point(0.5, 0.5),
        rotationType: RotationType.Rotate,
        zIndex: 0.0,
        scale: 0.2,
      ),
      name: 'icon',
    );
    view.accuracyCircle.fillColor = fm.Colors.blue.withAlpha(100);
    dev.log('Custom icons applied');
  }

  @override
  void onObjectRemoved(UserLocationView view) {}

  @override
  void onObjectUpdated(UserLocationView view, ObjectEvent event) {}

  // Метод для увеличения масштаба карты
  void _zoomIn() {
    final currentPosition = _mapWindow?.map.cameraPosition;
    if (currentPosition != null) {
      final newZoom = currentPosition.zoom + 1.0;
      // Ограничиваем максимальный зум (например, 20)
      final clampedZoom = math.min(newZoom, 20.0);
      _mapWindow?.map.moveWithAnimation(
        CameraPosition(
          currentPosition.target,
          zoom: clampedZoom,
          azimuth: currentPosition.azimuth,
          tilt: currentPosition.tilt,
        ),
        const Animation(AnimationType.Smooth,
            duration: 0.2), // Плавная анимация 0.5 сек
      );
    }
  }

  // Метод для уменьшения масштаба карты
  void _zoomOut() {
    final currentPosition = _mapWindow?.map.cameraPosition;
    if (currentPosition != null) {
      final newZoom = currentPosition.zoom - 1;
      // Ограничиваем минимальный зум (например, 0)
      final clampedZoom = math.max(newZoom, 0.0);
      _mapWindow?.map.moveWithAnimation(
        CameraPosition(
          currentPosition.target,
          zoom: clampedZoom,
          azimuth: currentPosition.azimuth,
          tilt: currentPosition.tilt,
        ),
        const Animation(AnimationType.Smooth,
            duration: 0.2), // Плавная анимация 0.5 сек
      );
    }
  }
}
