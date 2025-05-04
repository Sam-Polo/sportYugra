import 'package:yandex_maps_mapkit/mapkit.dart';

class PlacemarkData {
  final String name;
  final String description;
  final Point location;

  const PlacemarkData({
    required this.name,
    required this.description,
    required this.location,
  });
}
