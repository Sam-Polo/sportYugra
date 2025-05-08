import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Создает PlacemarkData из документа Firestore
  factory PlacemarkData.fromFirestore(DocumentSnapshot doc) {
    // Получаем данные как dynamic и приводим к нужным типам
    final dynamic rawData = doc.data();
    if (rawData == null) {
      return PlacemarkData(
        name: '',
        description: '',
        location: Point(latitude: 0, longitude: 0),
      );
    }

    // Извлекаем местоположение
    final dynamic rawLocation = rawData['location'];
    final GeoPoint geoPoint = rawLocation as GeoPoint;

    // Извлекаем строки
    final dynamic rawName = rawData['name'];
    final dynamic rawDescription = rawData['description'];

    // Извлекаем списки
    List<String> extractStringList(dynamic rawList) {
      if (rawList == null) return [];
      if (rawList is List) {
        return rawList.map((item) => item.toString()).toList();
      }
      return [];
    }

    final dynamic rawPhotoUrls = rawData['photoUrls'];
    final dynamic rawTags = rawData['tags'];

    return PlacemarkData(
      name: rawName?.toString() ?? '',
      description: rawDescription?.toString() ?? '',
      location: Point(
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
      ),
      photoUrls: extractStringList(rawPhotoUrls),
      tags: extractStringList(rawTags),
    );
  }
}
