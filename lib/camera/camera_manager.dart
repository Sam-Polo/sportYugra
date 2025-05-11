import 'dart:async';
import 'package:yandex_maps_mapkit/mapkit.dart';
import '../location/location_listener_impl.dart';
import 'camera_position_listener.dart';
import 'dart:developer' as dev;

class CameraManager {
  final MapWindow _mapWindow;
  final LocationManager _locationManager;

  late final _locationListener = LocationListenerImpl(
    onLocationUpdate: (location) {
      _location = location;
      if (_isLocationUnknown) {
        _isLocationUnknown = false;
      }
    },
    onLocationStatusUpdate: (locationStatus) {},
  );

  Location? _location;
  var _isLocationUnknown = true;

  static const _mapDefaultZoom = 15.0;

  CameraManager(this._mapWindow, this._locationManager);

  void moveCameraToUserLocation() {
    _location?.let((location) {
      final map = _mapWindow.map;
      final cameraPosition = map.cameraPosition;
      final newZoom = cameraPosition.zoom < _mapDefaultZoom
          ? _mapDefaultZoom
          : cameraPosition.zoom;

      final newCameraPosition = CameraPosition(
        location.position,
        zoom: newZoom,
        azimuth: cameraPosition.azimuth,
        tilt: 0.0,
      );

      map.moveWithAnimation(
        newCameraPosition,
        const Animation(AnimationType.Smooth, duration: 1.0),
      );
    });
  }

  void start() {
    _stop();
    _locationManager.subscribeForLocationUpdates(
      LocationSubscriptionSettings(
        LocationUseInBackground.Disallow,
        Purpose.General,
      ),
      _locationListener,
    );
  }

  void dispose() {
    _stop();
  }

  void _stop() {
    _locationManager.unsubscribe(_locationListener);
  }
}

extension _NullableExtension<T> on T? {
  void let(Function(T value) block) {
    if (this != null) {
      block(this as T);
    }
  }
}
