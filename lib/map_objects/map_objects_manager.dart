import 'dart:developer' as dev;
import 'package:flutter/material.dart' hide ImageProvider;
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/image.dart';
import '../data/placemarks/placemark_model.dart';
import '../listeners/map_object_tap_listener.dart';
import 'dart:math' as math;

/// Класс для управления объектами на карте (плейсмарки, кластеры, полилинии и др.)
class MapObjectsManager {
  final MapWindow _mapWindow;
  final Function(MapObject, Point) onMapObjectTap;

  // Коллекция для плейсмарков
  late final MapObjectCollection _mapObjectCollection;

  // Слушатель нажатия на объекты карты
  late final MapObjectTapListenerImpl _mapObjectTapListener;

  // Иконка для плейсмарка (общая для всех объектов)
  late final ImageProvider _placemarkIcon;

  // Флаг, показывающий инициализированы ли объекты на карте
  bool _isInitialized = false;

  MapObjectsManager(this._mapWindow, {required this.onMapObjectTap}) {
    _mapObjectTapListener =
        MapObjectTapListenerImpl(onMapObjectTapped: _onMapObjectTapped);

    _mapObjectCollection = _mapWindow.map.mapObjects.addCollection();

    // Загружаем иконку для плейсмарков
    _placemarkIcon = ImageProvider.fromImageProvider(
        const AssetImage('assets/images/Yandex_Maps_icon.png'));

    dev.log('MapObjectsManager created');
  }

  /// Добавляет список спортивных объектов на карту
  void addPlacemarks(List<PlacemarkData> placemarks) {
    if (!_isInitialized) {
      _isInitialized = true;
    }

    for (final placemark in placemarks) {
      _addPlacemark(placemark);
    }

    dev.log('Added ${placemarks.length} placemarks to map');
  }

  /// Добавляет один спортивный объект на карту
  void _addPlacemark(PlacemarkData placemark) {
    // Создаем плейсмарк
    final mapObject = _mapObjectCollection.addPlacemark();

    // Настраиваем плейсмарк
    mapObject.geometry = placemark.location;
    mapObject.setIcon(_placemarkIcon);
    mapObject.setIconStyle(IconStyle(
      anchor: const math.Point(0.5, 0.5),
      scale: 0.1,
      zIndex: 1,
      rotationType: RotationType.NoRotation,
    ));
    mapObject.userData = placemark;

    // Добавляем слушатель нажатия
    mapObject.addTapListener(_mapObjectTapListener);
  }

  /// Очищает все объекты с карты
  void clear() {
    _mapObjectCollection.clear();
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
    dev.log('MapObjectsManager disposed');
  }

  /// Проверяет инициализирована ли коллекция объектов
  bool get isInitialized => _isInitialized;
}
