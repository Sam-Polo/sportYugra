import 'package:yandex_maps_mapkit/mapkit.dart';

/// Модель данных для плейсмарка на карте
class PlacemarkData {
  final String id; // идентификатор объекта
  final String name;
  final String? description;
  final Point location;
  final List<String> tags;
  final List<String>? photoUrls; // URLs фотографий объекта
  final String? address; // Адрес объекта
  final String? phone; // Телефон объекта

  PlacemarkData({
    required this.id,
    required this.name,
    this.description,
    required this.location,
    this.tags = const [],
    this.photoUrls,
    this.address,
    this.phone,
  });
}
