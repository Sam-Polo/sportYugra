import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' show Point;
import 'placemark_model.dart';
import 'dart:developer' as dev;
import '../tags/firestore_tags.dart';

class FirestorePlacemarks {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreTags _firestoreTags = FirestoreTags();

  /// Загружает базовую информацию о спортивных объектах из Firestore (быстрая загрузка)
  Future<List<PlacemarkData>> getSportObjectsBasic() async {
    try {
      final snapshot = await _firestore.collection('sportobjects').get();
      final placemarks = <PlacemarkData>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Извлекаем только координаты и название (минимум для отображения)
          final geoPoint = data['location'] as GeoPoint?;
          if (geoPoint == null) continue;

          // Создаем объект PlacemarkData только с базовой информацией
          final placemark = PlacemarkData(
            id: doc.id,
            name: data['name'] as String? ?? 'Объект',
            description: null, // Загрузим позже
            location: Point(
              latitude: geoPoint.latitude,
              longitude: geoPoint.longitude,
            ),
            tags: [], // Загрузим позже
            photoUrls: null, // Загрузим позже
            address: null, // Загрузим позже
            phone: null, // Загрузим позже
          );

          placemarks.add(placemark);
        } catch (e) {
          dev.log('Ошибка при обработке документа: $e');
        }
      }

      dev.log('Базовая информация загружена: ${placemarks.length} объектов');
      return placemarks;
    } catch (e) {
      dev.log('Ошибка при загрузке объектов: $e');
      return [];
    }
  }

  /// Загружает полную информацию о спортивных объектах из Firestore
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
          if (geoPoint == null) continue;

          // Извлекаем photo-urls если они есть
          List<String>? photoUrls;
          if (data.containsKey('photo-urls')) {
            try {
              photoUrls = List<String>.from(data['photo-urls'] ?? []);
            } catch (e) {
              // Ошибка обработки фото
            }
          }

          // Извлекаем адрес если он есть
          String? address;
          if (data.containsKey('address')) {
            address = data['address'] as String?;
          }

          // Извлекаем телефон если он есть
          String? phone;
          if (data.containsKey('phone')) {
            phone = data['phone'] as String?;
          }

          // Загружаем теги объекта через FirestoreTags
          List<String> tagIds = [];
          try {
            // Загружаем теги для объекта
            final objectTags = await _firestoreTags.loadTagsForObject(doc.id);
            if (objectTags.isNotEmpty) {
              // Получаем ID тегов для фильтрации
              tagIds = objectTags.map((tag) => tag.id).toList();
            }
          } catch (e) {
            // Ошибка загрузки тегов
          }

          // Создаем объект PlacemarkData
          final placemark = PlacemarkData(
            id: doc.id,
            name: data['name'] as String? ?? 'Неизвестный объект',
            description: data['description'] as String?,
            location: Point(
              latitude: geoPoint.latitude,
              longitude: geoPoint.longitude,
            ),
            tags: tagIds,
            photoUrls: photoUrls,
            address: address,
            phone: phone,
          );

          placemarks.add(placemark);
        } catch (e) {
          dev.log('Ошибка при обработке документа: $e');
        }
      }

      dev.log('Полная информация загружена: ${placemarks.length} объектов');
      return placemarks;
    } catch (e) {
      dev.log('Ошибка при загрузке объектов: $e');
      return [];
    }
  }

  /// Обновляет объекты дополнительной информацией
  Future<void> updatePlacemarksWithDetails(
      List<PlacemarkData> placemarks) async {
    dev.log('Начинаем обновление объектов дополнительной информацией...');

    // Предварительно загружаем все теги для кэширования
    await _firestoreTags.loadAllTags();

    for (int i = 0; i < placemarks.length; i++) {
      final placemark = placemarks[i];

      try {
        // Загружаем документ объекта
        final doc =
            await _firestore.collection('sportobjects').doc(placemark.id).get();
        if (!doc.exists) continue;

        final data = doc.data()!;

        // Обновляем описание
        if (data.containsKey('description')) {
          placemark.description = data['description'] as String?;
        }

        // Обновляем фото
        if (data.containsKey('photo-urls')) {
          try {
            placemark.photoUrls = List<String>.from(data['photo-urls'] ?? []);
          } catch (e) {
            // Ошибка обработки фото
          }
        }

        // Обновляем адрес
        if (data.containsKey('address')) {
          placemark.address = data['address'] as String?;
        }

        // Обновляем телефон
        if (data.containsKey('phone')) {
          placemark.phone = data['phone'] as String?;
        }

        // Загружаем теги объекта
        try {
          final objectTags =
              await _firestoreTags.loadTagsForObject(placemark.id);
          if (objectTags.isNotEmpty) {
            placemark.tags = objectTags.map((tag) => tag.id).toList();
          }
        } catch (e) {
          // Ошибка загрузки тегов
        }
      } catch (e) {
        dev.log('Ошибка при обновлении объекта ${placemark.id}: $e');
      }

      // Обновляем статус каждые 10 объектов
      if (i % 10 == 0) {
        dev.log('Обновлено ${i + 1} из ${placemarks.length} объектов');
      }
    }

    dev.log('Обновление объектов завершено');
  }
}
