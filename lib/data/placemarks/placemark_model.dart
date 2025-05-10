import 'package:yandex_maps_mapkit/mapkit.dart';

class PlacemarkData {
  final String name;
  final String description;
  final Point location;
  final List<String> photoUrls;
  final List<String> tags;

  const PlacemarkData({
    required this.name,
    required this.description,
    required this.location,
    this.photoUrls = const [],
    this.tags = const [],
  });
}
