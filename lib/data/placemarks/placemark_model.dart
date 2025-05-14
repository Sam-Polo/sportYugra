import 'package:yandex_maps_mapkit/mapkit.dart';

/// Модель данных для плейсмарка на карте
class PlacemarkData {
  final String id; // идентификатор объекта
  final String name;
  String? description;
  final Point location;
  List<String> tags;
  List<String>? photoUrls; // URLs фотографий объекта
  String? address; // Адрес объекта
  String? phone; // Телефон объекта

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
