// lib\scenes\search_screen.dart
import 'package:flutter/material.dart' as fm;
import 'dart:developer' as dev;
import 'map_screen.dart';
import '../data/tags/firestore_tags.dart';
import '../data/tags/tag_model.dart';
import '../data/placemarks/firestore_placemarks.dart';
import '../data/placemarks/placemark_model.dart';
import '../widgets/object_details_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:collection';

class SearchScreen extends fm.StatefulWidget {
  // Принимаем активные фильтры и расстояния до объектов
  final List<String> activeTagFilters;
  final HashMap<String, double> objectDistances;

  const SearchScreen({
    super.key,
    this.activeTagFilters = const [],
    required this.objectDistances,
  });

  @override
  fm.State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends fm.State<SearchScreen> {
  // Контроллер и FocusNode для управления текстовым полем
  late fm.TextEditingController _searchController;
  late fm.FocusNode _searchFocusNode;

  // Флаг для отслеживания, установлен ли фокус
  bool _focusRequested = false;

  // Сервис для работы с тегами и объектами
  final _firestoreTags = FirestoreTags();
  final _firestorePlacemarks = FirestorePlacemarks();

  // Состояние загрузки и данные тегов
  bool _isLoading = false;
  List<TagData> _rootTags = [];
  List<TagData> _allTags = []; // Все теги (для поиска)
  List<PlacemarkData> _allPlacemarks = []; // Все объекты (для поиска)

  // Для хранения выбранных тегов (id тега -> выбран/не выбран)
  final Map<String, bool> _selectedTags = {};

  // Для отслеживания развернутых/свернутых тегов
  final Set<String> _expandedTags = {};

  // Для анимации появления блока иерархии
  bool _showHierarchy = false;

  // Для отображения результатов поиска
  String _searchQuery = '';
  bool _showSearchResults = false;
  List<dynamic> _searchResults =
      []; // Может содержать TagData или PlacemarkData

  // Константы для цветов
  final fm.Color _startColor = const fm.Color(0xFFFC4C4C); // Новый красный цвет
  final fm.Color _endColor = fm.Colors.white; // Белый
  final fm.Color _checkboxInactiveColor =
      const fm.Color.fromARGB(255, 63, 62, 62); // Цвет для неактивного чекбокса

  // Для анимации подсветки иерархии
  bool _isHierarchyHighlighted = false;

  @override
  void initState() {
    super.initState();
    _searchController = fm.TextEditingController();
    _searchFocusNode = fm.FocusNode();

    // Добавляем слушатель для обновления поиска при вводе текста
    _searchController.addListener(_onSearchChanged);

    // задержка (равна длительности анимации перехода)
    fm.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusRequested) {
        _focusRequested = true;
        Future.delayed(const Duration(milliseconds: 0), () {
          if (mounted) {
            _searchFocusNode.requestFocus();
            dev.log('Focus requested after hero animation');
          }
        });
      }
    });

    // Инициализируем выбранные теги на основе переданных фильтров
    _initSelectedTags();

    // Загружаем теги и объекты
    _loadData();
  }

  /// Инициализирует выбранные теги на основе активных фильтров
  void _initSelectedTags() {
    // Если есть активные фильтры, отмечаем их как выбранные
    for (final tagId in widget.activeTagFilters) {
      _selectedTags[tagId] = true;
    }

    dev.log('Инициализированы выбранные теги: $_selectedTags');
  }

  /// Загружает теги и объекты
  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _showHierarchy = false; // Скрываем иерархию до загрузки
      });
    }

    try {
      // Пытаемся загрузить теги из кеша
      dev.log('Пытаемся загрузить теги из кеша');
      final rootTags = await _firestoreTags.getCachedTags();

      // Собираем все теги (корневые и дочерние) для поиска
      final allTags = <TagData>[];
      _collectAllTags(rootTags, allTags);

      // Загружаем все объекты с полной информацией для поиска
      // Используем getSportObjects вместо getSportObjectsBasic, чтобы получить адреса
      final placemarks = await _firestorePlacemarks.getSportObjects();
      dev.log('Загружено ${placemarks.length} объектов с полной информацией');

      // Проверяем наличие адресов
      int objectsWithAddress = 0;
      for (final placemark in placemarks) {
        if (placemark.address != null && placemark.address!.isNotEmpty) {
          objectsWithAddress++;
        }
      }
      dev.log(
          'Объектов с адресами: $objectsWithAddress из ${placemarks.length}');

      // Автоматически раскрываем тег "тренажерный зал"
      _expandGymTags(rootTags);

      // Раскрываем теги, которые выбраны
      _expandSelectedTags(rootTags);

      // Выводим сокращенную информацию о тегах
      dev.log(
          'Загружено ${rootTags.length} корневых тегов и ${allTags.length} всего тегов');

      if (mounted) {
        setState(() {
          _rootTags = rootTags;
          _allTags = allTags;
          _allPlacemarks = placemarks;
          _isLoading = false;

          // Запускаем анимацию появления после небольшой задержки
          Future.delayed(const Duration(milliseconds: 0), () {
            if (mounted) {
              setState(() {
                _showHierarchy = true;
              });
            }
          });
        });
      }
    } catch (e) {
      dev.log('Ошибка при загрузке данных: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showHierarchy = true; // Показываем даже при ошибке
        });
      }
    }
  }

  /// Раскрывает теги, которые выбраны
  void _expandSelectedTags(List<TagData> tags) {
    for (final tagId in _selectedTags.keys) {
      if (_selectedTags[tagId] == true) {
        final tag = _findTagById(tagId);
        if (tag != null) {
          _expandParentsOfTag(tag);
        }
      }
    }
  }

  /// Рекурсивно собирает все теги в один список
  void _collectAllTags(List<TagData> tags, List<TagData> result) {
    for (final tag in tags) {
      result.add(tag);
      _collectAllTags(tag.childrenTags, result);
    }
  }

  /// Обрабатывает изменения в поисковой строке
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _showSearchResults = false;
      });
      return;
    }

    // Ищем совпадения среди тегов и объектов
    final results = <dynamic>[];

    // Поиск по тегам
    for (final tag in _allTags) {
      if (tag.name.toLowerCase().contains(query)) {
        results.add(tag);
        if (results.length >= 9) break; // Увеличиваем до 9 результатов
      }
    }

    // Если еще есть место для результатов, ищем среди объектов
    if (results.length < 9) {
      // Увеличиваем до 9 результатов
      for (final placemark in _allPlacemarks) {
        if (placemark.name.toLowerCase().contains(query)) {
          results.add(placemark);
          if (results.length >= 9) break; // Увеличиваем до 9 результатов
        }
      }
    }

    setState(() {
      _searchQuery = query;
      _searchResults = results;
      _showSearchResults = results.isNotEmpty;
    });
  }

  /// Рекурсивно выводит информацию об иерархии тегов для отладки
  void _logTagsHierarchy(List<TagData> tags, [int level = 0]) {
    // Метод оставлен, но без содержимого - чтобы не выводить подробную информацию о тегах
  }

  /// Автоматически раскрывает тег "тренажерный зал" и его родительские теги
  void _expandGymTags(List<TagData> tags) {
    // Более тщательный поиск тега тренажерного зала
    for (final tag in tags) {
      final tagNameLower = tag.name.toLowerCase();
      final tagIdLower = tag.id.toLowerCase();

      // Проверяем разные варианты названий и ID для тренажерного зала
      if (tagNameLower.contains('тренажерн') ||
          tagNameLower.contains('трена') ||
          tagIdLower.contains('gym') ||
          tagIdLower.contains('тренажер')) {
        _expandedTags.add(tag.id);

        // Если у тега есть родитель, нужно раскрыть и его
        TagData? currentParent = tag.parentTag;
        while (currentParent != null) {
          _expandedTags.add(currentParent.id);
          currentParent = currentParent.parentTag;
        }
      }
    }

    // Если тегов тренажерного зала не найдено, выводим сообщение
    if (_expandedTags.isEmpty) {
      dev.log('ВНИМАНИЕ: Теги тренажерного зала не найдены!');
    }
  }

  /// Проверяет, является ли тег тренажерным залом
  bool _isGymTag(TagData tag) {
    final tagNameLower = tag.name.toLowerCase();
    final tagIdLower = tag.id.toLowerCase();

    return tagNameLower.contains('тренажерн') ||
        tagNameLower.contains('трена') ||
        tagIdLower.contains('gym') ||
        tagIdLower.contains('тренажер');
  }

  /// Находит тег по его ID
  TagData? _findTagById(String tagId) {
    for (final tag in _allTags) {
      if (tag.id == tagId) return tag;
    }
    return null;
  }

  /// Обрабатывает выбор тега
  void _toggleTagSelection(String tagId, bool value) {
    setState(() {
      if (value) {
        _selectedTags[tagId] = true;
      } else {
        _selectedTags.remove(tagId);
      }
    });
  }

  /// Обрабатывает выбор объекта из результатов поиска
  void _onPlacemarkSelected(PlacemarkData placemark) {
    // Уже нет необходимости загружать полную информацию об объекте перед показом,
    // так как мы уже получили полную информацию при загрузке данных
    dev.log(
        'Открываем страницу объекта: ${placemark.name}, адрес: "${placemark.address ?? ""}"');

    // Создаем идентификатор объекта для поиска расстояния
    final placemarkId =
        '${placemark.name}_${placemark.location.latitude}_${placemark.location.longitude}';

    // Получаем расстояние до объекта, если оно есть
    final distance = widget.objectDistances[placemarkId];

    dev.log(
        'Расстояние до объекта: ${distance != null ? "${distance.toStringAsFixed(1)} м" : "неизвестно"}');

    // Закрываем поиск и открываем страницу объекта
    fm.Navigator.of(context).pop();

    // Показываем детали объекта
    fm.showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: fm.Colors.transparent,
      builder: (context) => ObjectDetailsSheet(
        placemark: placemark,
        distance: distance, // Передаем расстояние
      ),
    );
  }

  @override
  void dispose() {
    // Освобождаем ресурсы
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    // Проверяем, есть ли выбранные теги
    final bool hasSelectedTags = _selectedTags.values.contains(true);

    // Список названий выбранных тегов для отображения
    final List<String> selectedTagNames = [];
    if (hasSelectedTags) {
      for (final tagId in _selectedTags.keys) {
        if (_selectedTags[tagId] == true) {
          final tag = _findTagById(tagId);
          if (tag != null) {
            selectedTagNames.add(tag.name);
          }
        }
      }
    }

    return fm.Scaffold(
      backgroundColor: fm.Colors.black, // Черный фон
      resizeToAvoidBottomInset:
          false, // Отключаем автоматическую подстройку под клавиатуру
      body: fm.Stack(
        children: [
          fm.Column(
            children: [
              fm.SafeArea(
                child: fm.Padding(
                  padding:
                      const fm.EdgeInsets.only(left: 16, right: 16, top: 2),
                  child: fm.Column(
                    mainAxisSize: fm.MainAxisSize.min,
                    children: [
                      // Поисковая строка с Hero анимацией
                      fm.Hero(
                        tag: 'searchBarHero',
                        child: fm.Material(
                          color: fm.Colors.transparent,
                          child: MapSearchBar(
                            isButton: false,
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            autoFocus: false,
                            onChanged: (text) {
                              // Обработка происходит в _onSearchChanged
                            },
                          ),
                        ),
                      ),

                      // Кнопка разворачивания подсказок (если поиск не пустой, но подсказки скрыты)
                      if (_searchQuery.isNotEmpty && !_showSearchResults)
                        fm.InkWell(
                          onTap: () {
                            setState(() {
                              _showSearchResults = true;
                            });
                          },
                          child: fm.Container(
                            width: double.infinity,
                            margin: const fm.EdgeInsets.only(top: 4),
                            padding: const fm.EdgeInsets.symmetric(vertical: 8),
                            decoration: fm.BoxDecoration(
                              color: fm.Colors.grey.shade900,
                              borderRadius: fm.BorderRadius.circular(8),
                            ),
                            child: const fm.Center(
                              child: fm.Icon(
                                fm.Icons.keyboard_arrow_down,
                                color: fm.Colors.white70,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Область для отображения иерархии тегов
              fm.Expanded(
                child: _isLoading
                    ? const fm
                        .SizedBox() // заменяем спиннер на пустой контейнер
                    : _buildTagsHierarchyView(selectedTagNames),
              ),

              // Кнопка "Применить" - всегда видима, но может быть неактивной
              fm.SafeArea(
                child: fm.Padding(
                  padding: const fm.EdgeInsets.all(16.0),
                  child: fm.Align(
                    alignment: fm.Alignment.bottomRight,
                    child: fm.ElevatedButton(
                      onPressed: hasSelectedTags
                          ? _applyFilters
                          : null, // Неактивна, если нет выбранных тегов
                      style: fm.ElevatedButton.styleFrom(
                        backgroundColor:
                            hasSelectedTags ? _startColor : fm.Colors.grey,
                        foregroundColor: fm.Colors.white,
                        padding: const fm.EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 12.0),
                        // Убеждаемся, что кнопка всегда видима
                        disabledBackgroundColor: fm.Colors.grey,
                        disabledForegroundColor: fm.Colors.white70,
                      ),
                      child: const fm.Text(
                        'Применить',
                        style: fm.TextStyle(fontSize: 16.0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Результаты поиска поверх основного контента (если есть)
          if (_showSearchResults)
            fm.Positioned(
              top: fm.MediaQuery.of(context).padding.top +
                  50, // Позиционируем под строкой поиска
              left: 16,
              right: 16,
              child: _buildSearchResults(),
            ),
        ],
      ),
    );
  }

  /// Строит выпадающий список с результатами поиска
  fm.Widget _buildSearchResults() {
    return fm.Material(
      color: fm.Colors.transparent,
      elevation: 8,
      child: fm.Container(
        width: double.infinity,
        constraints: const fm.BoxConstraints(maxHeight: 300),
        decoration: fm.BoxDecoration(
          color: fm.Colors.black,
          border: fm.Border.all(color: fm.Colors.grey.shade800),
          borderRadius: fm.BorderRadius.circular(8),
          boxShadow: [
            fm.BoxShadow(
              color: fm.Colors.black.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: fm.Column(
          mainAxisSize: fm.MainAxisSize.min,
          children: [
            // Результаты поиска
            fm.Flexible(
              child: fm.ListView.builder(
                shrinkWrap: true,
                padding: fm.EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];

                  if (result is TagData) {
                    return _buildTagSearchResult(result);
                  } else if (result is PlacemarkData) {
                    return _buildPlacemarkSearchResult(result);
                  }

                  return const fm.SizedBox();
                },
              ),
            ),

            // Кнопка сворачивания
            fm.InkWell(
              onTap: () {
                setState(() {
                  _showSearchResults = false;
                  // Очищаем строку поиска при сворачивании
                  _searchController.clear();
                });
              },
              child: fm.Container(
                width: double.infinity,
                padding: const fm.EdgeInsets.symmetric(vertical: 8),
                decoration: fm.BoxDecoration(
                  color: fm.Colors.grey.shade900,
                  borderRadius: const fm.BorderRadius.only(
                    bottomLeft: fm.Radius.circular(8),
                    bottomRight: fm.Radius.circular(8),
                  ),
                ),
                child: const fm.Center(
                  child: fm.Icon(
                    fm.Icons.keyboard_arrow_up,
                    color: fm.Colors.white70,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строит элемент результата поиска для тега
  fm.Widget _buildTagSearchResult(TagData tag) {
    // Находим родительский тег для отображения
    final parentName = tag.parentTag?.name ?? '';

    return fm.InkWell(
      onTap: () {
        // При нажатии на элемент тега (не на чекбокс)
        // отмечаем тег (переключаем состояние чекбокса)
        final newValue = !(_selectedTags[tag.id] ?? false);
        _toggleTagSelection(tag.id, newValue);

        setState(() {
          // Скрываем результаты поиска, но не очищаем строку
          _showSearchResults = false;

          // Запускаем анимацию подсветки иерархии
          _isHierarchyHighlighted = true;
        });

        // Находим тег в иерархии и раскрываем его родителей
        _expandParentsOfTag(tag);

        // Сбрасываем подсветку через некоторое время
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isHierarchyHighlighted = false;
            });
          }
        });
      },
      child: fm.Padding(
        padding: const fm.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: fm.Row(
          children: [
            // Иконка тега
            fm.Container(
              width: 8,
              height: 8,
              decoration: fm.BoxDecoration(
                color: fm.Colors.grey.shade400,
                shape: fm.BoxShape.circle,
              ),
            ),
            const fm.SizedBox(width: 12),

            // Название тега (расширенное)
            fm.Expanded(
              flex: 2, // Увеличиваем вес основного названия
              child: fm.Text(
                tag.name,
                style: const fm.TextStyle(
                  color: fm.Colors.white,
                  fontSize: 16,
                ),
                overflow: fm.TextOverflow.ellipsis,
              ),
            ),

            // Родительский тег (если есть) с ограниченной шириной
            if (parentName.isNotEmpty)
              fm.Expanded(
                flex: 1, // Уменьшаем вес родительского названия
                child: fm.Text(
                  parentName,
                  style: fm.TextStyle(
                    color: fm.Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  overflow: fm.TextOverflow.ellipsis,
                  textAlign: fm.TextAlign.right,
                ),
              ),

            const fm.SizedBox(width: 8),

            // Чекбокс (фиксированной ширины)
            fm.SizedBox(
              width: 42, // Фиксированная ширина для чекбокса
              child: fm.Theme(
                data: fm.ThemeData(
                  checkboxTheme: fm.CheckboxThemeData(
                    fillColor: fm.MaterialStateProperty.resolveWith<fm.Color>(
                      (states) {
                        if (states.contains(fm.MaterialState.selected)) {
                          return _startColor;
                        }
                        return const fm.Color.fromARGB(255, 63, 62,
                            62); // Серый цвет для неактивного чекбокса
                      },
                    ),
                    checkColor: fm.MaterialStateProperty.all(fm.Colors.black),
                  ),
                ),
                child: fm.Checkbox(
                  value: _selectedTags[tag.id] ?? false,
                  onChanged: (value) {
                    _toggleTagSelection(tag.id, value ?? false);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строит элемент результата поиска для объекта
  fm.Widget _buildPlacemarkSearchResult(PlacemarkData placemark) {
    // Адрес объекта для отображения
    final address = placemark.address ?? '';

    // Отладочный вывод для проверки адреса
    dev.log('Отображаем объект в поиске: ${placemark.name}, адрес: "$address"');

    return fm.InkWell(
      onTap: () => _onPlacemarkSelected(placemark),
      child: fm.Padding(
        padding: const fm.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: fm.Row(
          crossAxisAlignment: fm.CrossAxisAlignment.center,
          children: [
            // Иконка объекта
            const fm.Icon(
              fm.Icons.place,
              color: fm.Colors.red,
              size: 20,
            ),
            const fm.SizedBox(width: 12),

            // Название и адрес в вертикальном расположении
            fm.Expanded(
              child: fm.Column(
                crossAxisAlignment: fm.CrossAxisAlignment.start,
                mainAxisSize: fm.MainAxisSize.min,
                children: [
                  // Название объекта
                  fm.Text(
                    placemark.name,
                    style: const fm.TextStyle(
                      color: fm.Colors.white,
                      fontSize: 16,
                    ),
                    overflow: fm.TextOverflow.ellipsis,
                  ),

                  // Адрес объекта (если есть)
                  if (address.isNotEmpty)
                    fm.Text(
                      address,
                      style: const fm.TextStyle(
                        color: fm.Colors.grey,
                        fontSize: 14,
                      ),
                      overflow: fm.TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Раскрывает все родительские теги для указанного тега
  void _expandParentsOfTag(TagData tag) {
    // Добавляем сам тег в список развернутых
    setState(() {
      _expandedTags.add(tag.id);

      // Раскрываем родительские теги
      TagData? currentParent = tag.parentTag;
      while (currentParent != null) {
        _expandedTags.add(currentParent.id);
        currentParent = currentParent.parentTag;
      }
    });
  }

  /// Применение выбранных фильтров
  void _applyFilters() {
    // Получаем список ID выбранных тегов
    final selectedTagIds = _selectedTags.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    dev.log('Выбранные теги: $selectedTagIds');

    // Возвращаемся на экран карты с выбранными тегами
    if (mounted) {
      // Закрываем экран поиска и передаем выбранные теги обратно
      fm.Navigator.of(context).pop(selectedTagIds);
    }
  }

  /// Строит представление иерархии тегов
  fm.Widget _buildTagsHierarchyView(List<String> selectedTagNames) {
    if (_rootTags.isEmpty) {
      return const fm.Center(
        child: fm.Text(
          'Теги не найдены',
          style: fm.TextStyle(color: fm.Colors.white54),
        ),
      );
    }

    return fm.Padding(
      padding: const fm.EdgeInsets.all(16.0),
      child: fm.Column(
        crossAxisAlignment: fm.CrossAxisAlignment.start,
        children: [
          const fm.Text(
            'Фильтры по тегам:',
            style: fm.TextStyle(
              color: fm.Colors.white,
              fontSize: 18,
              fontWeight: fm.FontWeight.bold,
            ),
          ),
          const fm.SizedBox(height: 16),

          // Блок иерархии тегов (расширяемый)
          fm.Expanded(
            child: fm.AnimatedOpacity(
              opacity: _showHierarchy ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 900),
              curve: fm.Curves.easeInOut,
              child: fm.AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: fm.BoxDecoration(
                  color: _isHierarchyHighlighted
                      ? fm.Colors.grey.withOpacity(0.15)
                      : fm.Colors.black,
                  borderRadius: fm.BorderRadius.circular(8),
                ),
                padding: const fm.EdgeInsets.all(8),
                child: fm.SingleChildScrollView(
                  child: fm.Column(
                    crossAxisAlignment: fm.CrossAxisAlignment.start,
                    children: _buildTagsList(),
                  ),
                ),
              ),
            ),
          ),

          // Информация о выбранных тегах
          if (selectedTagNames.isNotEmpty)
            fm.Padding(
              padding: const fm.EdgeInsets.only(top: 16.0),
              child: fm.Row(
                crossAxisAlignment: fm.CrossAxisAlignment.start,
                children: [
                  fm.Text(
                    'Выбраны теги: ',
                    style: fm.TextStyle(
                      color: fm.Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                  fm.Expanded(
                    child: fm.Text(
                      selectedTagNames.join(', '),
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 14,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Создает список корневых тегов
  List<fm.Widget> _buildTagsList() {
    // Проверка наличия корневых тегов
    if (_rootTags.isEmpty) {
      dev.log('[Поиск] Нет корневых тегов для отображения');
      return [];
    }

    final result = <fm.Widget>[];

    for (final rootTag in _rootTags.where((tag) => tag.parent == null)) {
      result.add(_buildTagItem(rootTag, 0));
    }

    return result;
  }

  /// Рекурсивно строит элемент дерева тегов
  fm.Widget _buildTagItem(TagData tag, int level) {
    // Используем childrenTags из модели вместо поиска по parent
    final childTags = tag.childrenTags;
    final bool hasChildren = childTags.isNotEmpty;
    final bool isExpanded = _expandedTags.contains(tag.id);
    final bool isGymTag = _isGymTag(tag);

    // Отладочная информация только для критических случаев
    if (isGymTag && childTags.isEmpty) {
      dev.log('ВНИМАНИЕ: Тег тренажерного зала не имеет дочерних тегов');
    }

    // Вычисляем цвет текста на основе уровня в иерархии
    // Максимальный уровень для градации цвета (предполагаем не более 5 уровней)
    const maxLevel = 5;
    double factor = level / maxLevel;
    if (factor > 1.0) factor = 1.0;

    // Интерполируем между начальным и конечным цветом
    fm.Color textColor = fm.Color.lerp(_startColor, _endColor, factor)!;

    return fm.Column(
      crossAxisAlignment: fm.CrossAxisAlignment.start,
      children: [
        fm.InkWell(
          onTap: () {
            setState(() {
              if (hasChildren) {
                // Если есть дочерние элементы, переключаем их видимость
                if (_expandedTags.contains(tag.id)) {
                  _expandedTags.remove(tag.id);
                } else {
                  _expandedTags.add(tag.id);
                }
              }

              // В любом случае, переключаем состояние чекбокса
              if (!isGymTag) {
                final newValue = !(_selectedTags[tag.id] ?? false);
                _toggleTagSelection(tag.id, newValue);
              }
            });
          },
          child: fm.Padding(
            padding: fm.EdgeInsets.only(left: 8.0 * level),
            child: fm.Row(
              children: [
                // Иконка раскрытия/сворачивания для тегов с дочерними элементами
                if (hasChildren)
                  fm.Icon(
                    isExpanded
                        ? fm.Icons.keyboard_arrow_down
                        : fm.Icons.arrow_forward_ios,
                    color: textColor,
                    size: isExpanded ? 20 : 16,
                  )
                else
                  fm.SizedBox(width: 20), // для выравнивания

                // Название тега
                fm.Expanded(
                  child: fm.Text(
                    tag.name,
                    style: fm.TextStyle(
                      color: textColor,
                      fontSize: 14 +
                          (5 - level) *
                              0.5, // Немного уменьшаем размер для вложенных уровней
                      fontWeight: level == 0
                          ? fm.FontWeight.bold
                          : fm.FontWeight.normal,
                    ),
                  ),
                ),

                // Чекбокс для выбора тега (кроме тренажерного зала)
                if (!isGymTag)
                  fm.Theme(
                    data: fm.ThemeData(
                      checkboxTheme: fm.CheckboxThemeData(
                        fillColor:
                            fm.MaterialStateProperty.resolveWith<fm.Color>(
                          (states) {
                            if (states.contains(fm.MaterialState.selected)) {
                              return textColor; // Выбранный цвет фона чекбокса
                            }
                            return _checkboxInactiveColor; // Новый цвет для неактивного чекбокса
                          },
                        ),
                        checkColor: fm.MaterialStateProperty.all(
                            fm.Colors.black), // Цвет галочки всегда черный
                      ),
                    ),
                    child: fm.Checkbox(
                      value: _selectedTags[tag.id] ?? false,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedTags[tag.id] = true;
                          } else {
                            _selectedTags.remove(tag.id);
                          }
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Если тег развернут, отображаем его дочерние теги
        if (isExpanded && hasChildren)
          fm.Padding(
            padding: const fm.EdgeInsets.only(left: 12.0, top: 4.0),
            child: fm.Column(
              crossAxisAlignment: fm.CrossAxisAlignment.start,
              children: childTags
                  .map((childTag) => _buildTagItem(childTag, level + 1))
                  .toList(),
            ),
          ),

        // Добавляем небольшой отступ между тегами одного уровня
        fm.SizedBox(height: 4.0),
      ],
    );
  }
}
