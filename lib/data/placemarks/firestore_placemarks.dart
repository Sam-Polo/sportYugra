import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' show Point;
import 'placemark_model.dart';
import 'dart:developer' as dev;

class FirestorePlacemarks {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Загружает спортивные объекты из Firestore
  Future<List<PlacemarkData>> getSportObjects() async {
    try {
      final snapshot = await _firestore.collection('sportobjects').get();

      final placemarks = <PlacemarkData>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Извлекаем координаты
          final geoPoint = data['location'] as GeoPoint?;
          if (geoPoint == null) {
            dev.log('Пропускаем объект без координат: ${doc.id}');
            continue;
          }

          // Извлекаем photo-urls если они есть
          List<String>? photoUrls;
          if (data.containsKey('photo-urls')) {
            try {
              photoUrls = List<String>.from(data['photo-urls'] ?? []);
              dev.log(
                  'Найдены фото для объекта ${doc.id}: ${photoUrls.length}');
            } catch (e) {
              dev.log('Ошибка при извлечении photo-urls: $e');
            }
          }

          // Извлекаем адрес если он есть
          String? address;
          if (data.containsKey('address')) {
            address = data['address'] as String?;
            if (address != null) {
              dev.log('Найден адрес для объекта ${doc.id}');
            }
          }

          // Извлекаем телефон если он есть
          String? phone;
          if (data.containsKey('phone')) {
            phone = data['phone'] as String?;
            if (phone != null) {
              dev.log('Найден телефон для объекта ${doc.id}');
            }
          }

          // Создаем объект PlacemarkData
          final placemark = PlacemarkData(
            id: doc.id, // Добавляем id документа
            name: data['name'] as String? ?? 'Неизвестный объект',
            description: data['description'] as String?,
            location: Point(
              latitude: geoPoint.latitude,
              longitude: geoPoint.longitude,
            ),
            tags: List<String>.from(data['tagNames'] ?? []),
            photoUrls: photoUrls,
            address: address,
            phone: phone,
          );

          placemarks.add(placemark);
        } catch (e) {
          dev.log('Ошибка при обработке документа ${doc.id}: $e');
        }
      }

      dev.log(
          'Загружено ${placemarks.length} спортивных объектов из Firestore');
      return placemarks;
    } catch (e) {
      dev.log('Ошибка при загрузке спортивных объектов: $e');
      return [];
    }
  }
}
