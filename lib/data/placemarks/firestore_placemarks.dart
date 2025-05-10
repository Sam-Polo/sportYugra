import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' show Point;
import 'placemark_model.dart';
import 'dart:developer' as dev;

class FirestorePlacemarks {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // получение всех спортивных объектов из Firestore
  Future<List<PlacemarkData>> getSportObjects() async {
    try {
      // Получаем снимок коллекции
      final QuerySnapshot snapshot =
          await _firestore.collection('sportobjects').get();

      // Преобразуем документы в модели
      final List<PlacemarkData> placemarks = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Извлекаем данные из документа
          final String name = data['name'] as String;
          final String description = data['description'] as String;

          // Получаем GeoPoint из Firestore и конвертируем в Point для Yandex MapKit
          final GeoPoint geoPoint = data['location'] as GeoPoint;
          final Point location = Point(
            latitude: geoPoint.latitude,
            longitude: geoPoint.longitude,
          );

          // Извлекаем tags если они есть
          List<String> tags = [];
          if (data['tags'] != null) {
            tags = List<String>.from(data['tags'] as List<dynamic>);
          }

          // Извлекаем photoUrls если они есть
          List<String> photoUrls = [];
          if (data['photoUrls'] != null) {
            photoUrls = List<String>.from(data['photoUrls'] as List<dynamic>);
          }

          // Создаем объект PlacemarkData
          final PlacemarkData placemark = PlacemarkData(
            name: name,
            description: description,
            location: location,
            tags: tags,
            photoUrls: photoUrls,
          );

          placemarks.add(placemark);
          dev.log('Загружен объект: $name');
        } catch (e) {
          dev.log('Ошибка при обработке документа ${doc.id}: $e');
          // Пропускаем проблемный документ и продолжаем
        }
      }

      dev.log('Загружено ${placemarks.length} объектов из Firestore');
      return placemarks;
    } catch (e) {
      // Логирование ошибки
      dev.log('Ошибка при получении данных из Firestore: $e');
      return [];
    }
  }
}
