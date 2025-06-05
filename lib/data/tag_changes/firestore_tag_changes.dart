import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tag_change_model.dart';

/// Сервис для работы с историей изменений тегов объектов в Firestore
class FirestoreTagChanges {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Получает список всех изменений тегов, отсортированных по времени (новые сначала)
  /// Ограничение limit определяет максимальное количество загружаемых записей
  Future<List<TagChangeData>> getTagChanges({int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('tag_changes')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final changes = querySnapshot.docs
          .map((doc) => TagChangeData.fromFirestore(doc))
          .toList();

      // Загружаем дополнительную информацию для каждого изменения
      await _loadAdditionalData(changes);

      return changes;
    } catch (e) {
      dev.log('Ошибка при загрузке истории изменений тегов: $e');
      return [];
    }
  }

  /// Получает список изменений тегов для конкретного объекта
  Future<List<TagChangeData>> getTagChangesForObject(String objectId,
      {int limit = 20}) async {
    try {
      // Получаем ссылку на объект
      final objectRef = _firestore.collection('sportobjects').doc(objectId);

      final querySnapshot = await _firestore
          .collection('tag_changes')
          .where('object_id', isEqualTo: objectRef)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final changes = querySnapshot.docs
          .map((doc) => TagChangeData.fromFirestore(doc))
          .toList();

      // Загружаем дополнительную информацию для каждого изменения
      await _loadAdditionalData(changes);

      return changes;
    } catch (e) {
      dev.log(
          'Ошибка при загрузке истории изменений для объекта $objectId: $e');
      return [];
    }
  }

  /// Загружает дополнительную информацию для списка изменений
  Future<void> _loadAdditionalData(List<TagChangeData> changes) async {
    // Создаем уникальный список объектов для загрузки
    final objectRefs = <DocumentReference>{};
    // Создаем уникальный список тегов для загрузки
    final tagRefs = <DocumentReference>{};

    // Собираем все ссылки
    for (final change in changes) {
      objectRefs.add(change.objectRef);
      tagRefs.addAll(change.addedTags);
      tagRefs.addAll(change.deletedTags);
    }

    // Загружаем информацию об объектах
    final objectData = await _loadObjectsData(objectRefs.toList());

    // Загружаем информацию о тегах
    final tagData = await _loadTagsData(tagRefs.toList());

    // Обновляем данные для каждого изменения
    for (final change in changes) {
      // Устанавливаем имя объекта
      change.objectName = objectData[change.objectRef.id];

      // Устанавливаем имена добавленных тегов
      for (final tagRef in change.addedTags) {
        final tagName = tagData[tagRef.id];
        if (tagName != null) {
          change.addedTagNames.add(tagName);
        }
      }

      // Устанавливаем имена удаленных тегов
      for (final tagRef in change.deletedTags) {
        final tagName = tagData[tagRef.id];
        if (tagName != null) {
          change.deletedTagNames.add(tagName);
        }
      }
    }
  }

  /// Загружает названия объектов по их ссылкам
  Future<Map<String, String>> _loadObjectsData(
      List<DocumentReference> objectRefs) async {
    final result = <String, String>{};

    try {
      // Разбиваем запросы на батчи, если список большой
      for (int i = 0; i < objectRefs.length; i += 10) {
        final end = (i + 10 < objectRefs.length) ? i + 10 : objectRefs.length;
        final batch = objectRefs.sublist(i, end);

        final futures = batch.map((ref) => ref.get());
        final docs = await Future.wait(futures);

        for (final doc in docs) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('name')) {
              result[doc.id] = data['name'] as String? ?? 'Неизвестный объект';
            } else {
              result[doc.id] = 'Неизвестный объект';
            }
          } else {
            result[doc.id] = 'Удаленный объект';
          }
        }
      }
    } catch (e) {
      dev.log('Ошибка при загрузке данных объектов: $e');
    }

    return result;
  }

  /// Загружает названия тегов по их ссылкам
  Future<Map<String, String>> _loadTagsData(
      List<DocumentReference> tagRefs) async {
    final result = <String, String>{};

    try {
      // Разбиваем запросы на батчи, если список большой
      for (int i = 0; i < tagRefs.length; i += 10) {
        final end = (i + 10 < tagRefs.length) ? i + 10 : tagRefs.length;
        final batch = tagRefs.sublist(i, end);

        final futures = batch.map((ref) => ref.get());
        final docs = await Future.wait(futures);

        for (final doc in docs) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('name')) {
              result[doc.id] = data['name'] as String? ?? 'Неизвестный тег';
            } else {
              result[doc.id] = 'Неизвестный тег';
            }
          } else {
            result[doc.id] = 'Удаленный тег';
          }
        }
      }
    } catch (e) {
      dev.log('Ошибка при загрузке данных тегов: $e');
    }

    return result;
  }
}
