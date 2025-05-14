import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' show Point;
import 'placemark_model.dart';
import 'dart:developer' as dev;
import '../tags/firestore_tags.dart';

class FirestorePlacemarks {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreTags _firestoreTags = FirestoreTags();

  /// Загружает спортивные объекты из Firestore
  Future<List<PlacemarkData>> getSportObjects() async {
    try {
      final snapshot = await _firestore.collection('sportobjects').get();

      final placemarks = <PlacemarkData>[];

      // Предварительно загружаем все теги для кэширования
      await _firestoreTags.loadAllTags();

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

          // Загружаем теги объекта через FirestoreTags
          List<String> tagIds = [];
          try {
            // Загружаем теги для объекта
            final objectTags = await _firestoreTags.loadTagsForObject(doc.id);
            if (objectTags.isNotEmpty) {
              // Получаем ID тегов для фильтрации
              tagIds = objectTags.map((tag) => tag.id).toList();
              dev.log('Загружены теги для объекта ${doc.id}: $tagIds');
            } else {
              dev.log('Для объекта ${doc.id} не найдены теги');
            }
          } catch (e) {
            dev.log('Ошибка при загрузке тегов для объекта ${doc.id}: $e');
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
            tags: tagIds, // Используем загруженные ID тегов
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
