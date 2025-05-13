import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tag_model.dart';

/// Сервис для работы с тегами из Firestore
class FirestoreTags {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Кэш загруженных тегов для быстрого доступа
  final Map<String, TagData> _tagsCache = {};

  /// Загружает все теги и строит их иерархию
  Future<List<TagData>> loadAllTags() async {
    try {
      // Очищаем кэш перед загрузкой
      _tagsCache.clear();

      // Загружаем все теги из коллекции tags
      final tagsSnapshot = await _firestore.collection('tags').get();

      // Создаем объекты TagData для каждого документа
      for (final doc in tagsSnapshot.docs) {
        final tag = TagData.fromFirestore(doc);
        _tagsCache[tag.id] = tag;
        dev.log('Загружен тег: ${tag.name} (${tag.id})');
      }

      // Строим иерархию тегов
      _buildTagsHierarchy();

      // Проверяем на ошибки в иерархии
      _validateTagsHierarchy();

      // Возвращаем только корневые теги (без родителей)
      return _tagsCache.values.where((tag) => tag.parent == null).toList();
    } catch (e) {
      dev.log('Ошибка при загрузке тегов: $e');
      return [];
    }
  }

  /// Загружает теги для конкретного объекта
  Future<List<TagData>> loadTagsForObject(String objectId) async {
    try {
      // Получаем документ объекта
      final objectDoc =
          await _firestore.collection('sportobjects').doc(objectId).get();

      if (!objectDoc.exists || !objectDoc.data()!.containsKey('tags')) {
        dev.log('Объект не существует или не содержит тегов: $objectId');
        return [];
      }

      // Получаем список ссылок на теги
      final List<DocumentReference> tagRefs =
          List<DocumentReference>.from(objectDoc.data()!['tags'] ?? []);

      if (tagRefs.isEmpty) {
        dev.log('Объект не имеет тегов: $objectId');
        return [];
      }

      // Загружаем все теги, если кэш пуст
      if (_tagsCache.isEmpty) {
        await loadAllTags();
      }

      // Собираем теги объекта
      final objectTags = <TagData>[];
      for (final ref in tagRefs) {
        final tagId = ref.id;
        if (_tagsCache.containsKey(tagId)) {
          objectTags.add(_tagsCache[tagId]!);
        } else {
          // Если тег не в кэше, загружаем его отдельно
          try {
            final tagDoc = await ref.get();
            if (tagDoc.exists) {
              final tag = TagData.fromFirestore(tagDoc);
              _tagsCache[tag.id] = tag;
              objectTags.add(tag);
            }
          } catch (e) {
            dev.log('Ошибка при загрузке тега $tagId: $e');
          }
        }
      }

      return objectTags;
    } catch (e) {
      dev.log('Ошибка при загрузке тегов для объекта: $e');
      return [];
    }
  }

  /// Строит иерархию тегов на основе parent и children
  void _buildTagsHierarchy() {
    // Проходим по всем тегам и устанавливаем связи родитель-потомок
    for (final tag in _tagsCache.values) {
      // Устанавливаем родительский тег
      if (tag.parent != null) {
        final parentId = tag.parent!.id;
        if (_tagsCache.containsKey(parentId)) {
          tag.parentTag = _tagsCache[parentId];
          dev.log(
              'Установлен родитель для ${tag.name}: ${tag.parentTag?.name}');
        } else {
          dev.log(
              'ВНИМАНИЕ: Родительский тег не найден: $parentId для ${tag.name}');
        }
      }

      // Устанавливаем дочерние теги
      for (final childRef in tag.children) {
        final childId = childRef.id;
        if (_tagsCache.containsKey(childId)) {
          tag.childrenTags.add(_tagsCache[childId]!);
          dev.log(
              'Добавлен дочерний тег ${_tagsCache[childId]!.name} для ${tag.name}');
        } else {
          dev.log('ВНИМАНИЕ: Дочерний тег не найден: $childId для ${tag.name}');
        }
      }
    }
  }

  /// Проверяет корректность иерархии тегов
  void _validateTagsHierarchy() {
    int errorCount = 0;

    // Проверяем соответствие parent и children
    for (final tag in _tagsCache.values) {
      // Проверяем родителя
      if (tag.parent != null) {
        final parentId = tag.parent!.id;
        if (!_tagsCache.containsKey(parentId)) {
          dev.log(
              'ОШИБКА: Родительский тег не существует: $parentId для ${tag.name}');
          errorCount++;
        } else {
          // Проверяем, что родитель содержит этот тег в своих children
          final parentTag = _tagsCache[parentId]!;
          final hasChildRef = parentTag.children.any((ref) => ref.id == tag.id);
          if (!hasChildRef) {
            dev.log(
                'ОШИБКА: Родитель ${parentTag.name} не содержит ссылку на дочерний тег ${tag.name}');
            errorCount++;
          }
        }
      }

      // Проверяем дочерние теги
      for (final childRef in tag.children) {
        final childId = childRef.id;
        if (!_tagsCache.containsKey(childId)) {
          dev.log(
              'ОШИБКА: Дочерний тег не существует: $childId для ${tag.name}');
          errorCount++;
        } else {
          // Проверяем, что дочерний тег указывает на этот тег как на родителя
          final childTag = _tagsCache[childId]!;
          if (childTag.parent == null || childTag.parent!.id != tag.id) {
            dev.log(
                'ОШИБКА: Дочерний тег ${childTag.name} не указывает на ${tag.name} как на родителя');
            errorCount++;
          }
        }
      }
    }

    if (errorCount > 0) {
      dev.log('ВНИМАНИЕ: Найдено $errorCount ошибок в иерархии тегов');
    } else {
      dev.log('Иерархия тегов проверена, ошибок не найдено');
    }
  }

  /// Возвращает строковое представление иерархии тегов для отладки
  String getTagsHierarchyString() {
    final buffer = StringBuffer();

    // Находим корневые теги (без родителей)
    final rootTags =
        _tagsCache.values.where((tag) => tag.parent == null).toList();

    // Рекурсивно строим иерархию
    for (final rootTag in rootTags) {
      _appendTagHierarchy(buffer, rootTag, 0);
    }

    return buffer.toString();
  }

  /// Рекурсивно добавляет тег и его потомков в строковый буфер
  void _appendTagHierarchy(StringBuffer buffer, TagData tag, int level) {
    // Добавляем отступы в зависимости от уровня
    final indent = '  ' * level;
    buffer.writeln('$indent- ${tag.name}');

    // Рекурсивно добавляем дочерние теги
    for (final childTag in tag.childrenTags) {
      _appendTagHierarchy(buffer, childTag, level + 1);
    }
  }
}
