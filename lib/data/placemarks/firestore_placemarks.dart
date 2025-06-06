import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' show Point;
import 'placemark_model.dart';
import '../tags/tag_model.dart';
import 'dart:developer' as dev;
import '../tags/firestore_tags.dart';

class FirestorePlacemarks {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreTags _firestoreTags = FirestoreTags();

  /// Загружает базовую информацию о спортивных объектах из Firestore (быстрая загрузка)
  Future<List<PlacemarkData>> getSportObjectsBasic() async {
    try {
      // Получаем все документы из коллекции sportobjects
      final snapshot = await _firestore.collection('sportobjects').get();

      dev.log('Загружены базовые данные для ${snapshot.docs.length} объектов');

      // Преобразуем документы в объекты PlacemarkData
      final placemarks = <PlacemarkData>[];
      for (final doc in snapshot.docs) {
        try {
          // Создаем объект с минимально необходимыми данными
          final data = doc.data();

          if (data.containsKey('location') &&
              data['location'] != null &&
              data.containsKey('name') &&
              data['name'] != null) {
            // Получаем координаты
            final geoPoint = data['location'] as GeoPoint;

            // Создаем объект с базовой информацией
            final placemark = PlacemarkData(
              id: doc.id,
              name: data['name'] as String,
              location: Point(
                latitude: geoPoint.latitude,
                longitude: geoPoint.longitude,
              ),
            );

            placemarks.add(placemark);
          }
        } catch (e) {
          // Упрощаем логирование ошибок для отдельных документов
          dev.log(
              'Ошибка при обработке документа: ${e.toString().substring(0, 100)}...');
        }
      }

      return placemarks;
    } catch (e) {
      dev.log('Ошибка при получении базовых данных объектов: $e');
      return [];
    }
  }

  /// Загружает полную информацию о спортивных объектах из Firestore
  Future<List<PlacemarkData>> getSportObjects() async {
    try {
      // Если у нас уже есть объекты с базовой информацией, используем их
      List<PlacemarkData> placemarks = await getSportObjectsBasic();

      dev.log(
          'Загружается полная информация для ${placemarks.length} объектов...');

      // Предварительно загружаем все теги, чтобы использовать их кеш
      dev.log(
          '[Теги] Проверка кеша тегов перед загрузкой информации об объектах');
      if (!_firestoreTags.isTagsCached) {
        dev.log('[Теги] Кеш тегов пуст, предварительно загружаем все теги');
        await _firestoreTags.loadAllTags();
      } else {
        dev.log('[Теги] Используем кешированные теги для объектов');
      }

      int objectsProcessed = 0;
      final List<Future> loadTasks = [];

      // Для каждого объекта создаем задачу загрузки полной информации
      for (final placemark in placemarks) {
        loadTasks.add(
          _loadFullObjectInfo(placemark).then((_) {
            // Обновляем счетчик обработанных объектов
            objectsProcessed++;
            if (objectsProcessed % 5 == 0 ||
                objectsProcessed == placemarks.length) {
              dev.log(
                  'Загружена информация для $objectsProcessed объектов из ${placemarks.length}');
            }
          }),
        );
      }

      // Ожидаем завершения всех задач загрузки
      await Future.wait(loadTasks);

      // Выводим сводку о загруженных данных
      int objectsWithAddress = placemarks
          .where((p) => p.address != null && p.address!.isNotEmpty)
          .length;
      int objectsWithPhone = placemarks
          .where((p) => p.phone != null && p.phone!.isNotEmpty)
          .length;

      dev.log(
          'ИТОГО загружены данные: адресов - $objectsWithAddress, телефонов - $objectsWithPhone');
      dev.log('Завершена загрузка полной информации для всех объектов');

      return placemarks;
    } catch (e) {
      dev.log('Ошибка при получении объектов: $e');
      return [];
    }
  }

  /// Загружает полную информацию для одного объекта
  Future<void> _loadFullObjectInfo(PlacemarkData placemark) async {
    try {
      // Получаем документ объекта
      final doc =
          await _firestore.collection('sportobjects').doc(placemark.id).get();

      if (!doc.exists) {
        dev.log('Документ для объекта ${placemark.id} не найден');
        return;
      }

      final data = doc.data() ?? {};

      // Добавляем описание
      if (data.containsKey('description')) {
        placemark.description = data['description'] as String?;
        dev.log('Загружено описание для ${placemark.name}');
      }

      // Добавляем адрес
      if (data.containsKey('address')) {
        placemark.address = data['address'] as String?;
        dev.log('Загружен адрес для ${placemark.name}: ${placemark.address}');
      }

      // Добавляем телефон
      if (data.containsKey('phone')) {
        placemark.phone = data['phone'] as String?;
        dev.log('Загружен телефон для ${placemark.name}: ${placemark.phone}');
      }

      // Проверяем наличие фотографий
      if (data.containsKey('photo-urls') && data['photo-urls'] is List) {
        placemark.photoUrls = List<String>.from(data['photo-urls'] as List);
        if (placemark.photoUrls!.isNotEmpty) {
          dev.log(
              'Загружено ${placemark.photoUrls!.length} фото для ${placemark.name}');
        }
      } else {
        // Нормальная ситуация, если у объекта нет фотографий
        placemark.photoUrls = [];
      }

      // Загружаем теги для объекта
      if (data.containsKey('tags') && data['tags'] is List) {
        try {
          final List<TagData> tagObjects =
              await _firestoreTags.loadTagsForObject(placemark.id);
          // Преобразуем список объектов TagData в список идентификаторов String
          placemark.tags = tagObjects.map((tag) => tag.id).toList();
          dev.log(
              'Загружено ${placemark.tags.length} тегов для ${placemark.name}');

          // Расчет разнообразия оборудования
          if (placemark.tags.isNotEmpty) {
            // Получаем общее количество тегов в системе
            final int totalTagsCount = _firestoreTags.getAllTagsCount();
            // Рассчитываем коэффициент разнообразия - отношение количества тегов объекта к общему числу тегов
            final double diversity = totalTagsCount > 0
                ? placemark.tags.length / totalTagsCount.toDouble()
                : 0.0;
            // Ограничиваем значение в пределах от 0 до 1
            placemark.equipmentDiversity = diversity > 1.0 ? 1.0 : diversity;
            dev.log(
                'Коэффициент разнообразия оборудования для ${placemark.name}: ${(placemark.equipmentDiversity! * 100).toStringAsFixed(1)}%');
          }
        } catch (e) {
          dev.log('Ошибка при загрузке тегов для объекта ${placemark.id}: $e');
        }
      }
    } catch (e) {
      dev.log(
          'Ошибка при загрузке полной информации для объекта ${placemark.id}: $e');
    }
  }
}
