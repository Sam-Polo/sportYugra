import 'package:yandex_maps_mapkit/mapkit.dart';

class LocationListenerImpl implements LocationListener {
  final Function(Location) onLocationUpdate;
  final Function(LocationStatus) onLocationStatusUpdate;

  LocationListenerImpl({
    required this.onLocationUpdate,
    required this.onLocationStatusUpdate,
  });

  @override
  void onLocationUpdated(Location location) {
    onLocationUpdate(location);
  }

  @override
  void onLocationStatusUpdated(LocationStatus locationStatus) {
    onLocationStatusUpdate(locationStatus);
  }
}
