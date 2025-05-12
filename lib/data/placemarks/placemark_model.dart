import 'package:yandex_maps_mapkit/mapkit.dart';

class PlacemarkData {
  final String name;
  final String description;
  final Point location;
  final List<String> photoUrls;
  final List<String> tags;
  final String? address;
  final String? phone;
  final double? distance;

  const PlacemarkData({
    required this.name,
    required this.description,
    required this.location,
    this.photoUrls = const [],
    this.tags = const [],
    this.address,
    this.phone,
    this.distance,
  });
}
