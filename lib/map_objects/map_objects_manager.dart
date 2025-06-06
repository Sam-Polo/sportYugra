import 'dart:async';
import 'dart:developer' as dev;
import 'dart:core';
import 'package:flutter/material.dart' hide ImageProvider, TextStyle;
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/image.dart';
import '../data/placemarks/placemark_model.dart';
import '../listeners/map_object_tap_listener.dart';
import 'dart:math' as math;

/// Класс для управления объектами на карте (плейсмарки, кластеры, полилинии и др.)
class MapObjectsManager {
  final MapWindow _mapWindow;
  final Function(MapObject, Point) onMapObjectTap;

  // Стиль текста для плейсмарков (вынесен для переиспользования)
  static const TextStyle _placemarkTextStyle = TextStyle(
    size: 11.0,
    color: Color.fromARGB(255, 12, 0, 39),
    outlineColor: Color.fromARGB(255, 206, 191, 252),
    outlineWidth: 1.2,
    placement: TextStylePlacement.Bottom,
    offset: 4.0,
  );

  // Коллекция для плейсмарков
  late final MapObjectCollection _mapObjectCollection;

  // Слушатель нажатия на объекты карты
  late final MapObjectTapListenerImpl _mapObjectTapListener;

  // Иконка для плейсмарка (общая для всех объектов)
  late final ImageProvider _placemarkIcon;

  // Флаг, показывающий инициализированы ли объекты на карте
  bool _isInitialized = false;

  // Сет с идентификаторами добавленных плейсмарков для отслеживания уже добавленных
  final Set<String> _addedPlacemarkIds = {};

  // Словарь для хранения добавленных объектов по идентификатору (ключ - ID, значение - объект)
  final _placemarkObjects = <String, PlacemarkMapObject>{};

  // Сет для отслеживания плейсмарков, у которых сейчас отображается текст
  final Set<String> _placemarksWithVisibleText = {};

  // Список всех плейсмарков для фильтрации
  List<PlacemarkData> _allPlacemarks = [];

  // Активные фильтры (ID тегов)
  List<String> _activeTagFilters = [];

  // Для ограничения вывода логов фильтрации
  int _loggedFilterCheckCount = 0;

  // Флаг для детального логирования фильтрации
  bool _loggedFilterDetails = false;

  MapObjectsManager(this._mapWindow, {required this.onMapObjectTap}) {
    _mapObjectTapListener =
        MapObjectTapListenerImpl(onMapObjectTapped: _onMapObjectTapped);

    _mapObjectCollection = _mapWindow.map.mapObjects.addCollection();

    // Загружаем иконку для плейсмарков
    _placemarkIcon = ImageProvider.fromImageProvider(
        const AssetImage('assets/images/Yandex_Maps_icon.png'));

    dev.log('MapObjectsManager created');
  }

  /// Устанавливает активные фильтры тегов и обновляет отображаемые объекты
  void setTagFilters(List<String> tagIds) {
    _activeTagFilters = tagIds;
    dev.log('[Фильтры] Установлены фильтры тегов: $_activeTagFilters');

    // Если у нас уже есть плейсмарки, применяем к ним фильтры
    if (_allPlacemarks.isNotEmpty) {
      _refreshPlacemarks();
    }
  }

  /// Очищает все фильтры
  void clearFilters() {
    _activeTagFilters = [];
    dev.log('[Фильтры] Фильтры тегов очищены');

    // Если у нас уже есть плейсмарки, отображаем их все
    if (_allPlacemarks.isNotEmpty) {
      _refreshPlacemarks();
    }
  }

  /// Проверяет, соответствует ли плейсмарк текущим фильтрам
  bool _matchesFilters(PlacemarkData placemark) {
    // Если нет активных фильтров, показываем все объекты
    if (_activeTagFilters.isEmpty) {
      return true;
    }

    // Выводим детальный лог только для одного объекта, чтобы можно было убедиться в работе фильтров
    if (!_loggedFilterDetails && _loggedFilterCheckCount == 0) {
      dev.log(
          '[Фильтры] Детали фильтрации для проверки: объект ${placemark.name} с тегами: ${placemark.tags}');
      dev.log('[Фильтры] Активные фильтры: $_activeTagFilters');
      _loggedFilterDetails = true;
    }

    // Увеличиваем счетчик проверенных объектов (для лога)
    if (_loggedFilterCheckCount < 5) {
      _loggedFilterCheckCount++;
    }

    // Проверяем, содержит ли плейсмарк все выбранные теги
    for (final tagId in _activeTagFilters) {
      if (!placemark.tags.contains(tagId)) {
        return false; // Если хотя бы один тег не найден, объект не соответствует фильтрам
      }
    }

    // Если все теги найдены, объект соответствует фильтрам
    return true;
  }

  /// Обновляет отображение плейсмарков согласно текущим фильтрам
  void _refreshPlacemarks() {
    // Очищаем текущие объекты с карты
    _mapObjectCollection.clear();
    _addedPlacemarkIds.clear();
    _placemarkObjects.clear();
    _placemarksWithVisibleText.clear();

    // Фильтруем плейсмарки
    final filteredPlacemarks = _allPlacemarks.where(_matchesFilters).toList();
    dev.log(
        '[Фильтры] Отображено ${filteredPlacemarks.length} из ${_allPlacemarks.length} объектов');

    // Добавляем отфильтрованные плейсмарки на карту
    _addPlacemarksWithAnimation(filteredPlacemarks);
  }

  /// Добавляет список спортивных объектов на карту
  void addPlacemarks(List<PlacemarkData> placemarks) {
    if (!_isInitialized) {
      _isInitialized = true;
    }

    // Сохраняем все плейсмарки для возможности фильтрации
    _allPlacemarks = placemarks;

    // Фильтруем плейсмарки перед добавлением
    final filteredPlacemarks = placemarks.where(_matchesFilters).toList();
    dev.log(
        'Добавление ${filteredPlacemarks.length} из ${placemarks.length} объектов (применены фильтры: ${_activeTagFilters.isNotEmpty})');

    // Анимированное добавление плейсмарков с задержкой
    _addPlacemarksWithAnimation(filteredPlacemarks);
  }

  /// Добавляет плейсмарки с анимацией
  void _addPlacemarksWithAnimation(List<PlacemarkData> placemarks) {
    // Счетчик добавленных объектов
    int counter = 0;

    // Создаем список ID объектов которые должны быть на карте
    final Set<String> newPlacemarkIds = {};
    for (final placemark in placemarks) {
      final placemarkId = _getPlacemarkId(placemark);
      newPlacemarkIds.add(placemarkId);
    }

    // Удаляем объекты, которых больше нет в новом списке
    final idsToRemove = _addedPlacemarkIds.difference(newPlacemarkIds);
    for (final idToRemove in idsToRemove) {
      final objectToRemove = _placemarkObjects[idToRemove];
      if (objectToRemove != null) {
        _mapObjectCollection.remove(objectToRemove);
        _placemarkObjects.remove(idToRemove);
      }
    }
    _addedPlacemarkIds.removeAll(idsToRemove);

    // Добавляем новые плейсмарки с задержкой
    for (final placemark in placemarks) {
      // Создаем уникальный ID для плейсмарка
      final placemarkId = _getPlacemarkId(placemark);

      // Проверяем, был ли этот плейсмарк уже добавлен
      if (_addedPlacemarkIds.contains(placemarkId)) {
        continue; // Пропускаем уже добавленные плейсмарки
      }

      // Добавляем ID в список
      _addedPlacemarkIds.add(placemarkId);

      // Задержка для каждого следующего плейсмарка (80мс между объектами)
      Future.delayed(Duration(milliseconds: counter * 80), () {
        if (_isInitialized) {
          _addPlacemarkWithScale(placemark, placemarkId);
        }
      });

      counter++;
    }
  }

  /// Создает идентификатор для плейсмарка
  String _getPlacemarkId(PlacemarkData placemark) {
    return '${placemark.name}_${placemark.location.latitude}_${placemark.location.longitude}';
  }

  /// Добавляет один спортивный объект на карту с анимацией масштабирования
  void _addPlacemarkWithScale(PlacemarkData placemark, String placemarkId) {
    // Создаем плейсмарк
    final mapObject = _mapObjectCollection.addPlacemark();

    // Настраиваем плейсмарк
    mapObject.geometry = placemark.location;
    mapObject.setIcon(_placemarkIcon);

    // Установка имени объекта как текста (изначально текст виден)
    mapObject.setText(placemark.name);
    _placemarksWithVisibleText
        .add(placemarkId); // добавляем в сет видимых текстов

    // Настройка стиля текста для лучшей читаемости на светлом фоне
    mapObject.setTextStyle(
      _placemarkTextStyle,
    );

    // Начальный масштаб для анимации (иконка будет увеличиваться от 0 до нормального размера)
    mapObject.setIconStyle(IconStyle(
      anchor: const math.Point(0.5, 0.5),
      scale: 0.0, // Начальный размер - 0
      zIndex: 1,
      rotationType: RotationType.NoRotation,
    ));

    mapObject.userData = placemark;

    // Добавляем слушатель нажатия
    mapObject.addTapListener(_mapObjectTapListener);

    // Сохраняем объект в словаре для возможности его удаления при обновлении
    _placemarkObjects[placemarkId] = mapObject;

    // Анимация увеличения иконки
    _animateIconScale(mapObject);
  }

  /// Анимация масштабирования иконки
  void _animateIconScale(PlacemarkMapObject mapObject) {
    const animationDuration = Duration(milliseconds: 300);
    const int fps = 60;
    final int totalFrames = (animationDuration.inMilliseconds * fps) ~/ 1000;

    double currentScale = 0.0;
    const double targetScale = 0.1; // Итоговый размер иконки

    // Создаем таймер для анимации
    int frameCount = 0;
    Timer.periodic(const Duration(milliseconds: (1000 ~/ 60)), (timer) {
      frameCount++;

      if (frameCount > totalFrames) {
        timer.cancel();
        return;
      }

      // Рассчитываем следующий масштаб с помощью функции с эффектом отскока
      final progress = frameCount / totalFrames;
      currentScale = _bounceEaseOut(progress) * targetScale;

      // Обновляем стиль иконки
      mapObject.setIconStyle(IconStyle(
        anchor: const math.Point(0.5, 0.5),
        scale: currentScale,
        zIndex: 1,
        rotationType: RotationType.NoRotation,
      ));
    });
  }

  /// Функция плавности с эффектом отскока
  double _bounceEaseOut(double x) {
    const n1 = 7.5625;
    const d1 = 2.75;

    double result = x;

    if (x < 1 / d1) {
      return n1 * x * x;
    } else if (x < 2 / d1) {
      result = x - (1.5 / d1);
      return n1 * result * result + 0.75;
    } else if (x < 2.5 / d1) {
      result = x - (2.25 / d1);
      return n1 * result * result + 0.9375;
    } else {
      result = x - (2.625 / d1);
      return n1 * result * result + 0.984375;
    }
  }

  /// Очищает все объекты с карты
  void clear() {
    _mapObjectCollection.clear();
    _addedPlacemarkIds.clear();
    _placemarkObjects.clear();
    _placemarksWithVisibleText.clear(); // очищаем сет видимых текстов
    _isInitialized = false;
    dev.log('Cleared all map objects');
  }

  /// Обработчик нажатия на объект карты
  bool _onMapObjectTapped(MapObject mapObject, Point point) {
    dev.log('Map object tapped at: ${point.latitude}, ${point.longitude}');
    return onMapObjectTap(mapObject, point);
  }

  /// Освобождает ресурсы
  void dispose() {
    _mapObjectCollection.clear();
    _addedPlacemarkIds.clear();
    _placemarkObjects.clear();
    _placemarksWithVisibleText.clear(); // очищаем сет видимых текстов
    dev.log('MapObjectsManager disposed');
  }

  /// Проверяет инициализирована ли коллекция объектов
  bool get isInitialized => _isInitialized;

  // выполняет действие для каждого плейсмарка
  void forEachPlacemark(Function(PlacemarkMapObject, String) action) {
    _placemarkObjects.forEach((id, object) => action(object, id));
  }

  // устанавливает видимость текста для конкретного плейсмарка
  void setPlacemarkTextVisibility(String placemarkId, bool visible) {
    final placemarkObject = _placemarkObjects[placemarkId];
    final placemarkData = placemarkObject?.userData as PlacemarkData?;

    if (placemarkObject != null && placemarkData != null) {
      if (visible && !_placemarksWithVisibleText.contains(placemarkId)) {
        // показываем текст, если нужно и он сейчас скрыт
        placemarkObject.setText(placemarkData.name);
        // переустанавливаем стиль текста, чтобы убедиться, что он применился с видимым цветом
        placemarkObject.setTextStyle(
          _placemarkTextStyle,
        );
        _placemarksWithVisibleText.add(placemarkId);
      } else if (!visible && _placemarksWithVisibleText.contains(placemarkId)) {
        // скрываем текст, если нужно и он сейчас виден
        placemarkObject.setText(''); // устанавливаем пустую строку для скрытия
        _placemarksWithVisibleText.remove(placemarkId);
      }
    } else {
      dev.log(
          '[setPlacemarkTextVisibility] Объект или данные для $placemarkId не найдены.'); // для отладки
    }
  }

  // проверяет, показан ли текст у конкретного плейсмарка
  bool isPlacemarkTextVisible(String placemarkId) {
    return _placemarksWithVisibleText.contains(placemarkId);
  }

  /// Обновляет отображение объектов с текущими фильтрами
  void refreshWithFilters() {
    dev.log(
        '[Фильтры] Обновление объектов после получения детальной информации');
    if (_activeTagFilters.isNotEmpty) {
      // Если есть активные фильтры, перезапускаем фильтрацию на обновленных данных
      _refreshPlacemarks();
    }
  }

  /// Возвращает список всех плейсмарков
  List<PlacemarkData> getPlacemarks() {
    return [..._allPlacemarks]; // Возвращаем копию списка
  }
}
