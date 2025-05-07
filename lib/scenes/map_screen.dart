import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/image.dart';
import '../data/placemarks.dart';
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
  }

  void _initUserLocation() {
    if (_mapWindow == null) return;

    _userLocationLayer = mapkit.createUserLocationLayer(_mapWindow!)
      ..setVisible(true)
      ..setObjectListener(this);
    dev.log('UserLocationLayer initialized and listener set');

    _locationManager = mapkit.createLocationManager();
    _cameraManager = CameraManager(_mapWindow!, _locationManager!)..start();
  }

  void _addPlacemarks() {
    if (_mapWindow == null) return;
    for (final placemark in placemarks) {
      _mapWindow!.map.mapObjects.addPlacemark()
        ..geometry = placemark.location
        ..setText(placemark.name)
        ..setTextStyle(const TextStyle(
            size: 12.0, color: fm.Colors.black, outlineColor: fm.Colors.white))
        ..setIcon(ImageProvider.fromImageProvider(
            const fm.AssetImage("assets/images/Yandex_Maps_icon.png")))
        ..setIconStyle(const IconStyle(scale: 0.1));
    }
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
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

              _addPlacemarks();
              Permission.location.isGranted.then((isGranted) {
                if (isGranted) {
                  _initUserLocation();
                }
              });
            },
          ),
          fm.Positioned(
            right: 16,
            bottom: 16,
            child: MapControlButton(
              icon: fm.Icons.my_location_outlined,
              backgroundColor: fm.Colors.black,
              onPressed: () {
                _cameraManager?.moveCameraToUserLocation();
              },
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
}
