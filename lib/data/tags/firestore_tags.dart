import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tag_model.dart';

/// Сервис для работы с тегами из Firestore (реализация синглтона)
class FirestoreTags {
  // Синглтон инстанс
  static final FirestoreTags _instance = FirestoreTags._internal();

  // Фабрика для получения одного экземпляра
  factory FirestoreTags() {
    return _instance;
  }

  // Приватный конструктор
  FirestoreTags._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Кэш загруженных тегов для быстрого доступа
  final Map<String, TagData> _tagsCache = {};

  // Флаг, указывающий, что все теги уже загружены
  bool _allTagsLoaded = false;

  // Список корневых тегов (для быстрого доступа)
  List<TagData> _rootTagsList = [];

  /// Загружает все теги и строит их иерархию
  Future<List<TagData>> loadAllTags() async {
    // Если теги уже загружены, возвращаем их из кеша
    if (_allTagsLoaded) {
      dev.log(
          '[Теги] Возвращаем все теги из кеша (${_rootTagsList.length} корневых тегов)');
      return _rootTagsList;
    }

    try {
      // Очищаем кэш перед загрузкой
      _tagsCache.clear();
      dev.log('[Теги] Начинаем загрузку всех тегов из Firestore...');

      // Загружаем все теги из коллекции tags
      final tagsSnapshot = await _firestore.collection('tags').get();

      // Создаем объекты TagData для каждого документа
      for (final doc in tagsSnapshot.docs) {
        final tag = TagData.fromFirestore(doc);
        _tagsCache[tag.id] = tag;
      }

      // Строим иерархию тегов
      _buildTagsHierarchy();

      // Проверяем на ошибки в иерархии
      _validateTagsHierarchy();

      // Сохраняем корневые теги в отдельный список для быстрого доступа
      _rootTagsList =
          _tagsCache.values.where((tag) => tag.parent == null).toList();

      // Устанавливаем флаг, что все теги загружены
      _allTagsLoaded = true;

      dev.log(
          '[Теги] Загружено и кешировано ${_tagsCache.length} тегов (${_rootTagsList.length} корневых)');

      // Возвращаем только корневые теги (без родителей)
      return _rootTagsList;
    } catch (e) {
      dev.log('[Теги] Ошибка при загрузке тегов: $e');
      return [];
    }
  }

  /// Возвращает теги из кеша, если они уже загружены, или загружает их
  Future<List<TagData>> getCachedTags() async {
    if (_allTagsLoaded) {
      dev.log(
          '[Теги] КЕШИРОВАНИЕ: Используем ${_rootTagsList.length} корневых тегов из кеша (без загрузки из Firestore)');
      return _rootTagsList;
    } else {
      dev.log(
          '[Теги] КЕШИРОВАНИЕ: Теги не найдены в кеше, загружаем из Firestore...');
      return loadAllTags();
    }
  }

  /// Проверяет, загружены ли все теги
  bool get isTagsCached => _allTagsLoaded;

  /// Загружает теги для конкретного объекта
  Future<List<TagData>> loadTagsForObject(String objectId) async {
    try {
      // Получаем документ объекта
      final objectDoc =
          await _firestore.collection('sportobjects').doc(objectId).get();

      if (!objectDoc.exists || !objectDoc.data()!.containsKey('tags')) {
        return [];
      }

      // Получаем список ссылок на теги
      final List<DocumentReference> tagRefs =
          List<DocumentReference>.from(objectDoc.data()!['tags'] ?? []);

      if (tagRefs.isEmpty) {
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
            dev.log('[Теги] Ошибка при загрузке тега $tagId: $e');
          }
        }
      }

      return objectTags;
    } catch (e) {
      dev.log('[Теги] Ошибка при загрузке тегов для объекта: $e');
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
        }
      }

      // Устанавливаем дочерние теги
      for (final childRef in tag.children) {
        final childId = childRef.id;
        if (_tagsCache.containsKey(childId)) {
          tag.childrenTags.add(_tagsCache[childId]!);
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
              '[Теги] ОШИБКА: Родительский тег не существует: $parentId для ${tag.id}');
          errorCount++;
        } else {
          // Проверяем, что родитель содержит этот тег в своих children
          final parentTag = _tagsCache[parentId]!;
          final hasChildRef = parentTag.children.any((ref) => ref.id == tag.id);
          if (!hasChildRef) {
            dev.log(
                '[Теги] ОШИБКА: Родитель ${parentTag.id} не содержит ссылку на дочерний тег ${tag.id}');
            errorCount++;
          }
        }
      }

      // Проверяем дочерние теги
      for (final childRef in tag.children) {
        final childId = childRef.id;
        if (!_tagsCache.containsKey(childId)) {
          dev.log(
              '[Теги] ОШИБКА: Дочерний тег не существует: $childId для ${tag.id}');
          errorCount++;
        } else {
          // Проверяем, что дочерний тег указывает на этот тег как на родителя
          final childTag = _tagsCache[childId]!;
          if (childTag.parent == null || childTag.parent!.id != tag.id) {
            dev.log(
                '[Теги] ОШИБКА: Дочерний тег ${childTag.id} не указывает на ${tag.id} как на родителя');
            errorCount++;
          }
        }
      }
    }

    if (errorCount > 0) {
      dev.log('[Теги] ВНИМАНИЕ: Найдено $errorCount ошибок в иерархии тегов');
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

  /// Очищает кеш тегов (для тестирования)
  void clearCache() {
    _tagsCache.clear();
    _rootTagsList.clear();
    _allTagsLoaded = false;
    dev.log('[Теги] Кеш тегов очищен');
  }
}
