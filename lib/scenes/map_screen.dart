import 'dart:developer' as dev;
import 'dart:math' as math;
import 'dart:collection';
import 'dart:core';

import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' hide Map;
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../camera/camera_manager.dart';
import '../scenes/search_screen.dart';
import '../permissions/permission_manager.dart';
import '../widgets/map_control_button.dart';
import '../listeners/map_object_tap_listener.dart';
import '../data/placemarks/placemark_model.dart';
import '../data/placemarks/firestore_placemarks.dart';
import '../map_objects/map_objects_manager.dart';
import '../widgets/object_details_sheet.dart';
import '../data/tags/firestore_tags.dart';
import '../data/tags/tag_model.dart';
import 'dart:async';

/// Виджет поисковой строки, который может работать как кнопка или поле ввода
class MapSearchBar extends fm.StatelessWidget {
  final fm.TextEditingController? controller;
  final fm.FocusNode? focusNode;
  final bool autoFocus;
  final void Function(String)? onChanged;
  final bool isButton;
  final fm.VoidCallback? onTap;

  const MapSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.autoFocus = false,
    this.onChanged,
    this.isButton = false,
    this.onTap,
  });

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Material(
      color: fm.Colors.transparent,
      child: fm.InkWell(
        onTap: isButton ? onTap : null,
        child: fm.Container(
          decoration: fm.BoxDecoration(
            color: isButton ? const fm.Color(0xBF090230) : fm.Colors.white,
            borderRadius: fm.BorderRadius.circular(12),
          ),
          child: isButton
              ? _buildButtonContent(context)
              : _buildTextFieldContent(context),
        ),
      ),
    );
  }

  /// Строит содержимое MapSearchBar в режиме поля ввода (внутренняя часть)
  fm.Widget _buildTextFieldContent(fm.BuildContext context) {
    return fm.Container(
      padding: const fm.EdgeInsets.symmetric(
          horizontal: 12, vertical: 8), // Сохраняем padding внутри
      child: fm.Row(
        children: [
          const fm.Icon(
            fm.Icons.search,
            color: fm.Colors.black, // <- Черная иконка для белого фона
            size: 24,
          ),
          const fm.SizedBox(width: 8),
          fm.Expanded(
            child: fm.TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autoFocus,
              onChanged: onChanged,
              style: const fm.TextStyle(
                color: fm.Colors.black,
                fontSize: 18,
                fontWeight: fm.FontWeight.normal,
              ),
              decoration: const fm.InputDecoration(
                hintText: 'Поиск',
                hintStyle: fm.TextStyle(color: fm.Colors.grey),
                border: fm.InputBorder.none,
                contentPadding: fm.EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Строит содержимое MapSearchBar в режиме кнопки (внутренняя часть)
  fm.Widget _buildButtonContent(fm.BuildContext context) {
    return fm.Container(
      padding: const fm.EdgeInsets.symmetric(
          horizontal: 12, vertical: 8), // Сохраняем padding внутри
      child: fm.Row(
        children: [
          const fm.Icon(
            fm.Icons.search,
            color: fm.Colors.white,
            size: 24,
          ),
          const fm.SizedBox(width: 8),
          fm.Text(
            'Поиск', // Текст кнопки
            style: const fm.TextStyle(
              color: fm.Colors.white,
              fontSize: 18,
              fontWeight: fm.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class MapScreen extends fm.StatefulWidget {
  const MapScreen({super.key});

  @override
  fm.State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends fm.State<MapScreen>
    with fm.WidgetsBindingObserver
    implements UserLocationObjectListener, MapCameraListener {
  // Экземпляр Firestore для прямого доступа к данным
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Флаг для включения/отключения автоматического перемещения камеры к пользователю после загрузки и определения местоположения
  final bool _enableAutoCameraMove = false;

  // Флаг для отслеживания первоначальной инициализации
  bool _isInitiallyLoaded = false;

  MapWindow? _mapWindow;
  String? _mapStyle;
  UserLocationLayer? _userLocationLayer;
  LocationManager? _locationManager;
  CameraManager? _cameraManager;
  late final _permissionManager = const PermissionManager();

  // Менеджер объектов на карте
  MapObjectsManager? _mapObjectsManager;

  // Сервис для работы с Firestore
  final _firestorePlacemarks = FirestorePlacemarks();
  final _firestoreTags = FirestoreTags();

  // Флаг загрузки данных
  bool _isLoading = false;
  bool _placemarksLoaded = false; // флаг загрузки плейсмарков
  bool _locationInitialized = false; // флаг инициализации местоположения

  // Порог зума, ниже которого названия меток будут скрыты
  final double _textVisibilityZoomThreshold = 13.0;

  // Текущее местоположение пользователя
  Point? _userLocation;

  // Словарь для хранения расстояний до объектов (ключ - идентификатор объекта)
  final _objectDistances = HashMap<String, double>();

  // Флаг для отображения кнопки "Очистить фильтры"
  bool _hasActiveFilters = false;

  // Флаг для отображения кнопки refresh обновления данных (для отладки)
  static const bool _showRefreshButton = false;

  // Для хранения активных фильтров
  List<String> _activeTagFilters = [];

  // Для отслеживания изменений видимости текста
  bool _lastTextVisibility = false;

  @override
  void initState() {
    super.initState();
    fm.WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _requestLocationPermission();

    // Предварительно загружаем теги в кеш
    _firestoreTags.loadAllTags().then((tags) {
      dev.log(
          '[Теги] Предварительная загрузка тегов выполнена (${tags.length} корневых)');
    });

    dev.log('MapKit onStart');
    mapkit.onStart();
  }

  @override
  void dispose() {
    fm.WidgetsBinding.instance.removeObserver(this);
    _mapWindow?.map.removeCameraListener(this); // удаляем слушатель камеры
    _cameraManager?.dispose();
    _mapObjectsManager?.dispose();
    dev.log('MapKit onStop');
    mapkit.onStop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(fm.AppLifecycleState state) {
    if (state == fm.AppLifecycleState.resumed) {
      _requestLocationPermission();
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style_new.json');
      dev.log('Map style loaded');
      if (_mapWindow != null) {
        _mapWindow?.map.setMapStyle(_mapStyle!);
      }
    } catch (e) {
      dev.log('Error loading map style: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    final permissions = [PermissionType.accessLocation];
    await _permissionManager.tryToRequest(permissions);
    await _permissionManager.showRequestDialog(permissions);

    final status = await Permission.location.status;

    if (status.isGranted && _mapWindow != null && _locationManager != null) {
      dev.log(
          'Location permission granted, attempting to update location/camera');
      _cameraManager?.moveCameraToUserLocation();
    }
  }

  void _initUserLocation() {
    if (_mapWindow == null) return;

    Permission.location.isGranted.then((isGranted) {
      if (isGranted) {
        _userLocationLayer = mapkit.createUserLocationLayer(_mapWindow!)
          ..headingEnabled = true
          ..setVisible(true)
          ..setObjectListener(this);
        dev.log('UserLocationLayer initialized and listener set');

        _locationManager = mapkit.createLocationManager();
        _cameraManager = CameraManager(_mapWindow!, _locationManager!)..start();
        dev.log('LocationManager and CameraManager initialized');

        // Отмечаем, что местоположение инициализировано
        _locationInitialized = true;

        // Попытка переместить камеру после загрузки и получения местоположения
        _tryMoveCameraAfterLoadAndLocation();

        // Добавляем этот State как слушатель камеры
        _mapWindow?.map.addCameraListener(this);
      } else {
        dev.log(
            'Location permission not granted, skipping LocationManager and UserLocationLayer initialization');
      }
    });
  }

  // Обработчик нажатия на объект карты
  bool _onMapObjectTapped(MapObject mapObject, Point point) {
    // Проверяем, что это плейсмарк
    if (mapObject is PlacemarkMapObject) {
      final userData = mapObject.userData;
      if (userData != null && userData is PlacemarkData) {
        // Обновляем расстояние до объекта перед показом информации
        _updateDistanceToPlacemark(userData);
        _showPlacemarkInfo(userData, point);
        return true; // прекращаем обработку события
      }
    }
    return false; // продолжаем обработку события
  }

  // Обновляет расстояние до объекта на основе текущего положения пользователя
  void _updateDistanceToPlacemark(PlacemarkData placemark) {
    // Сначала пытаемся получить местоположение из CameraManager или из UserLocationView
    Point? userLocation = _cameraManager?.userLocation ?? _userLocation;

    // Если не удалось получить положение пользователя, используем положение камеры как запасной вариант
    if (userLocation == null && _mapWindow == null) return;

    try {
      // Получаем координаты для расчета расстояния
      final Point sourcePoint =
          userLocation ?? _mapWindow!.map.cameraPosition.target;

      // Рассчитываем расстояние между точками
      final double distanceInMeters = _calculateDistance(
          sourcePoint.latitude,
          sourcePoint.longitude,
          placemark.location.latitude,
          placemark.location.longitude);

      // Создаем уникальный идентификатор для объекта
      final placemarkId = _getPlacemarkId(placemark);

      // Сохраняем расстояние в словаре
      _objectDistances[placemarkId] = distanceInMeters;
    } catch (e) {
      dev.log('Ошибка при обновлении расстояния до объекта: $e');
    }
  }

  // Обновляет расстояния до всех объектов
  void _updateAllDistances() {
    if (_mapObjectsManager == null) return;

    _mapObjectsManager!.forEachPlacemark((placemarkObject, placemarkId) {
      final userData = placemarkObject.userData;
      if (userData != null && userData is PlacemarkData) {
        _updateDistanceToPlacemark(userData);
      }
    });
  }

  // Создает уникальный идентификатор для объекта
  String _getPlacemarkId(PlacemarkData placemark) {
    return '${placemark.name}_${placemark.location.latitude}_${placemark.location.longitude}';
  }

  // Рассчитывает расстояние между двумя точками
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Используем формулу гаверсинусов для расчета расстояния между точками
    const double earthRadius = 6371000; // радиус Земли в метрах

    // Перевод в радианы
    final double lat1Rad = lat1 * math.pi / 180;
    final double lon1Rad = lon1 * math.pi / 180;
    final double lat2Rad = lat2 * math.pi / 180;
    final double lon2Rad = lon2 * math.pi / 180;

    // Разница координат
    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;

    // Формула гаверсинусов
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    // Расстояние в метрах
    return earthRadius * c;
  }

  // Показывает информацию о плейсмарке
  void _showPlacemarkInfo(PlacemarkData placemark, Point point) {
    dev.log(
        'Показываем информацию о метке: ${placemark.name}, координаты: ${point.latitude}, ${point.longitude}');

    if (mounted) {
      // Получаем идентификатор объекта
      final placemarkId = _getPlacemarkId(placemark);

      // Получаем расстояние до объекта из словаря
      final distance = _objectDistances[placemarkId];

      // Проверяем, есть ли у плейсмарка адрес и телефон, которые нужны на детальной странице
      if ((placemark.address == null || placemark.address!.isEmpty) ||
          placemark.phone == null ||
          placemark.tags.isEmpty ||
          placemark.photoUrls == null) {
        dev.log(
            'У плейсмарка отсутствуют некоторые данные, загружаем детальную информацию');

        _loadPlacemarkDetails(placemark).then((_) {
          // После загрузки деталей показываем модальное окно
          _showObjectDetailsSheet(placemark, distance);
        });
      } else {
        // Если все данные уже есть, сразу показываем модальное окно
        _showObjectDetailsSheet(placemark, distance);
      }
    }
  }

  /// Загружает детальную информацию для конкретного плейсмарка
  Future<void> _loadPlacemarkDetails(PlacemarkData placemark) async {
    try {
      final doc =
          await _firestore.collection('sportobjects').doc(placemark.id).get();

      if (!doc.exists) {
        dev.log('Документ для объекта ${placemark.id} не найден');
        return;
      }

      final data = doc.data() ?? {};

      // Обновляем данные плейсмарка
      if (data.containsKey('description')) {
        placemark.description = data['description'] as String?;
      }

      if (data.containsKey('address')) {
        placemark.address = data['address'] as String?;
        dev.log('Загружен адрес для ${placemark.name}: ${placemark.address}');
      }

      if (data.containsKey('phone')) {
        placemark.phone = data['phone'] as String?;
        dev.log('Загружен телефон для ${placemark.name}: ${placemark.phone}');
      }

      // Проверяем только "photo-urls", так как именно это поле используется в Firestore
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

      dev.log(
          'Загрузка детальной информации для объекта ${placemark.name} завершена');
    } catch (e) {
      dev.log(
          'Ошибка при загрузке детальной информации для объекта ${placemark.id}: $e');
    }
  }

  /// Показывает модальное окно с деталями объекта
  void _showObjectDetailsSheet(PlacemarkData placemark, double? distance) {
    fm.showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: fm.Colors.transparent,
      builder: (context) => ObjectDetailsSheet(
        placemark: placemark,
        distance: distance, // Передаем расстояние отдельным параметром
      ),
    );
  }

  /// Загружает плейсмарки из Firestore
  Future<void> _loadPlacemarksFromFirestore() async {
    if (_mapWindow != null) {
      if (_placemarksLoaded) {
        return;
      }

      try {
        setState(() {
          _isLoading = true;
        });

        // Загружаем базовую информацию в первую очередь
        final placemarks = await _firestorePlacemarks.getSportObjectsBasic();
        dev.log(
            'Загружено ${placemarks.length} объектов с базовой информацией');

        // Создаем менеджер объектов карты
        _mapObjectsManager = MapObjectsManager(
          _mapWindow!,
          onMapObjectTap: _onMapObjectTapped,
        );

        // Добавляем объекты на карту сразу с базовой информацией
        _mapObjectsManager?.addPlacemarks(placemarks);

        // После добавления объектов принудительно обновляем зум,
        // чтобы убедиться, что названия отображаются корректно
        _updateCameraForNameVisibility();

        // Загружаем детальную информацию в фоне
        _loadDetailedInfoInBackground();

        setState(() {
          _isLoading = false;
          _placemarksLoaded = true;
        });
      } catch (e) {
        dev.log('Ошибка при загрузке объектов: $e');
        // Показываем снекбар с ошибкой
        if (mounted) {
          fm.ScaffoldMessenger.of(context).showSnackBar(
            fm.SnackBar(
                content: fm.Text('Ошибка загрузки объектов: ${e.toString()}')),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Принудительно обновляем позицию камеры, чтобы названия объектов отображались корректно
  void _updateCameraForNameVisibility() {
    if (_mapWindow != null) {
      // Получаем текущую позицию камеры
      final currentPos = _mapWindow!.map.cameraPosition;

      dev.log(
          '[Видимость] Корректировка камеры для обновления видимости названий объектов');

      // Создаем новую позицию с минимальным изменением долготы
      final newPos = CameraPosition(
        Point(
          latitude: currentPos.target.latitude,
          longitude:
              currentPos.target.longitude + 0.000001, // Минимальное изменение
        ),
        zoom: currentPos.zoom,
        azimuth: currentPos.azimuth,
        tilt: currentPos.tilt,
      );

      // Перемещаем камеру на новую позицию, чтобы сработал слушатель изменения камеры
      _mapWindow!.map.moveWithAnimation(
        newPos,
        const Animation(AnimationType.Smooth,
            duration: 0.1), // Быстрая и незаметная анимация
      );

      // Дополнительный вызов обновления видимости текста
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _mapWindow != null) {
          _updatePlacemarkTextVisibility(_mapWindow!.map.cameraPosition.zoom);
          dev.log(
              '[Видимость] Дополнительный вызов обновления видимости названий объектов');
        }
      });
    }
  }

  /// Загружает детальную информацию об объектах в фоновом режиме
  Future<void> _loadDetailedInfoInBackground() async {
    try {
      // Загружаем детальную информацию об объектах в фоне
      final detailedPlacemarks = await _firestorePlacemarks.getSportObjects();
      dev.log(
          'Получена полная информация об объектах: ${detailedPlacemarks.length}');

      // Устанавливаем фильтры тегов, если они есть
      if (_activeTagFilters.isNotEmpty) {
        _mapObjectsManager?.setTagFilters(_activeTagFilters);
      }

      // Добавляем объекты с полной информацией на карту
      _mapObjectsManager?.addPlacemarks(detailedPlacemarks);

      // Обновляем отображение объектов на карте с учетом фильтров и новой информации
      _mapObjectsManager?.refreshWithFilters();

      // Принудительно обновляем позицию камеры для корректного отображения названий
      // после загрузки всех объектов
      _updateCameraForNameVisibility();

      dev.log('Завершена загрузка детальной информации об объектах');
    } catch (e) {
      dev.log('Ошибка при загрузке детальной информации: $e');
    }
  }

  // Попытка переместить камеру к пользователю, если местоположение получено и плейсмарки загружены
  void _tryMoveCameraAfterLoadAndLocation() {
    // Проверяем флаг автоматического перемещения камеры
    if (!_enableAutoCameraMove) {
      dev.log(
          'Автоматическое перемещение камеры отключено флагом _enableAutoCameraMove');
      return; // Если флаг false, выходим из функции
    }

    if (_cameraManager != null && _locationInitialized && _placemarksLoaded) {
      // Добавляем задержку в 1 секунду перед перемещением камеры
      Future.delayed(const Duration(seconds: 1), () {
        _cameraManager?.moveCameraToUserLocation();
        dev.log(
            'Attempting to move camera after load and location init with 1s delay');
      });
    }
  }

  // Обновляет видимость текста у всех плейсмарков в зависимости от уровня зума
  void _updatePlacemarkTextVisibility(double currentZoom) {
    // если менеджер объектов не инициализирован, выходим
    if (_mapObjectsManager == null) return;

    // определяем, нужно ли показывать текст на текущем зуме
    final bool showText = currentZoom >= _textVisibilityZoomThreshold;

    // вывод логгера только при изменении состояния видимости
    if (showText != _lastTextVisibility) {
      dev.log(
          '[Видимость] Изменена видимость названий объектов: ${showText ? "показаны" : "скрыты"} (зум: $currentZoom)');
      _lastTextVisibility = showText;
    }

    // перебираем все добавленные плейсмарки и обновляем их видимость текста через менеджер объектов
    _mapObjectsManager?.forEachPlacemark((placemarkObject, placemarkId) {
      _mapObjectsManager?.setPlacemarkTextVisibility(placemarkId, showText);
    });
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
      body: fm.Stack(
        children: [
          YandexMap(
            onMapCreated: (mapWindow) {
              _mapWindow = mapWindow;

              if (_mapStyle != null) {
                _mapWindow?.map.setMapStyle(_mapStyle!);
              }

              _mapWindow?.map.move(
                CameraPosition(
                  Point(latitude: 60.988094, longitude: 69.037551),
                  zoom: 12.7,
                  azimuth: 0.0,
                  tilt: 17.0,
                ),
              );

              _initUserLocation();

              // Загружаем плейсмарки из Firestore
              _loadPlacemarksFromFirestore();
            },
          ),
          // Search bar
          fm.Positioned(
            // Positioned задает положение для всего блока (Padding + Hero + MapSearchBar)
            left: 0,
            right: 0,
            top: 0, // Прижимаем к верху
            child: fm.Padding(
              padding: const fm.EdgeInsets.only(left: 0, right: 0, top: 40),
              child: fm.Hero(
                tag: 'searchBarHero',
                child: fm.Container(
                  margin: const fm.EdgeInsets.symmetric(horizontal: 16),
                  child: MapSearchBar(
                    isButton: true,
                    onTap: () {
                      _openSearchScreen(context);
                    },
                  ),
                ),
              ),
            ),
          ),
          // Индикатор загрузки
          if (_isLoading)
            const fm.Positioned.fill(
              child: fm.Center(
                child: fm.CircularProgressIndicator(),
              ),
            ),
          // Кнопка обновления данных
          if (_showRefreshButton)
            fm.Positioned(
              left: 16,
              bottom: 16,
              child: fm.Container(
                decoration: fm.BoxDecoration(
                  color: const fm.Color(0xBF090230),
                  borderRadius: fm.BorderRadius.circular(8),
                ),
                child: fm.IconButton(
                  icon: const fm.Icon(fm.Icons.refresh, color: fm.Colors.white),
                  onPressed: _loadPlacemarksFromFirestore,
                  tooltip: 'Обновить данные',
                ),
              ),
            ),
          // Кнопки зума
          fm.Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: fm.Align(
              alignment: fm.Alignment.centerRight,
              child: fm.Column(
                mainAxisSize:
                    fm.MainAxisSize.min, // Колонку по размеру содержимого
                children: [
                  MapControlButton(
                    icon: fm.Icons.add,
                    backgroundColor: const fm.Color(0xBF090230),
                    iconColor: fm.Colors.white,
                    onPressed: _zoomIn,
                  ),
                  fm.SizedBox(height: 8), // Небольшой отступ между кнопками
                  MapControlButton(
                    icon: fm.Icons.remove,
                    backgroundColor: const fm.Color(0xBF090230),
                    iconColor: fm.Colors.white,
                    onPressed: _zoomOut,
                  ),
                  fm.SizedBox(
                      height:
                          8), // Отступ между кнопками зума и кнопкой местоположения
                  MapControlButton(
                    icon: fm.Icons.my_location_outlined,
                    backgroundColor: const fm.Color(0xBF090230),
                    iconColor: fm.Colors.white,
                    onPressed: () {
                      _cameraManager?.moveCameraToUserLocation();
                    },
                  ),
                ],
              ),
            ),
          ),
          // Кнопка "Очистить фильтры"
          if (_hasActiveFilters)
            fm.Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: fm.Center(
                child: fm.ElevatedButton(
                  onPressed: _clearAllFilters,
                  style: fm.ElevatedButton.styleFrom(
                    backgroundColor: const fm.Color(0xFFFC4C4C),
                    foregroundColor: fm.Colors.white,
                    padding: const fm.EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 12.0),
                  ),
                  child: const fm.Text(
                    'Очистить фильтры',
                    style: fm.TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void onObjectAdded(UserLocationView view) {
    dev.log('onObjectAdded called');
    view.arrow.setIcon(
      ImageProvider.fromImageProvider(
        const fm.AssetImage('assets/images/user_arrow_icon.png'),
      ),
    );
    view.arrow.setIconStyle(
      const IconStyle(
        anchor: math.Point(0.5, 0.5),
        rotationType: RotationType.Rotate,
        zIndex: 0.0,
        scale: 0.2,
      ),
    );
    final pinIcon = view.pin.useCompositeIcon();
    pinIcon.setIcon(
      ImageProvider.fromImageProvider(
          const fm.AssetImage('assets/images/my_location_icon.png')),
      const IconStyle(
        anchor: math.Point(0.5, 0.5),
        rotationType: RotationType.Rotate,
        zIndex: 0.0,
        scale: 0.2,
      ),
      name: 'icon',
    );
    view.accuracyCircle.fillColor = fm.Colors.blue.withAlpha(100);
    dev.log('Custom icons applied');
  }

  @override
  void onObjectRemoved(UserLocationView view) {}

  @override
  void onObjectUpdated(UserLocationView view, ObjectEvent event) {
    // Обновляем местоположение пользователя при любом изменении объекта
    _userLocation = view.pin.geometry;
    dev.log(
        'Местоположение пользователя обновлено: ${_userLocation?.latitude}, ${_userLocation?.longitude}');

    // Обновляем расстояния до всех объектов при изменении местоположения
    _updateAllDistances();
  }

  // Реализация MapCameraListener
  @override
  void onCameraPositionChanged(
    dynamic map,
    CameraPosition cameraPosition,
    CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    // вызываем нашу логику обновления видимости текста
    _updatePlacemarkTextVisibility(cameraPosition.zoom);
  }

  // Метод для увеличения масштаба карты
  void _zoomIn() {
    final currentPosition = _mapWindow?.map.cameraPosition;
    if (currentPosition != null) {
      final newZoom = currentPosition.zoom + 1.0;
      // Ограничиваем максимальный зум (например, 20)
      final clampedZoom = math.min(newZoom, 20.0);
      _mapWindow?.map.moveWithAnimation(
        CameraPosition(
          currentPosition.target,
          zoom: clampedZoom,
          azimuth: currentPosition.azimuth,
          tilt: currentPosition.tilt,
        ),
        const Animation(AnimationType.Smooth,
            duration: 0.2), // Плавная анимация 0.2 сек
      );
    }
  }

  // Метод для уменьшения масштаба карты
  void _zoomOut() {
    final currentPosition = _mapWindow?.map.cameraPosition;
    if (currentPosition != null) {
      final newZoom = currentPosition.zoom - 1;
      // Ограничиваем минимальный зум (например, 0)
      final clampedZoom = math.max(newZoom, 0.0);
      _mapWindow?.map.moveWithAnimation(
        CameraPosition(
          currentPosition.target,
          zoom: clampedZoom,
          azimuth: currentPosition.azimuth,
          tilt: currentPosition.tilt,
        ),
        const Animation(AnimationType.Smooth,
            duration: 0.2), // Плавная анимация 0.2 сек
      );
    }
  }

  /// Очищает все активные фильтры
  void _clearAllFilters() {
    // Очищаем список активных фильтров и скрываем кнопку очистки
    setState(() {
      _activeTagFilters.clear();
      _hasActiveFilters = false; // Скрываем кнопку очистки фильтров
    });

    // Обновляем отображение объектов с пустыми фильтрами
    _mapObjectsManager?.clearFilters();

    // Принудительно обновляем позицию камеры для корректного отображения названий
    _updateCameraForNameVisibility();
  }

  // Метод для открытия экрана поиска
  void _openSearchScreen(fm.BuildContext context) async {
    dev.log('Search bar tapped, initiating transition...');

    // Передаем предзагруженные объекты на экран поиска, чтобы избежать повторной загрузки
    List<PlacemarkData>? preloadedObjects;
    if (_mapObjectsManager != null) {
      preloadedObjects = _mapObjectsManager!.getPlacemarks();
      dev.log(
          'Передаем ${preloadedObjects.length} предзагруженных объектов на экран поиска');
    }

    // Открываем экран поиска и ждем результат (выбранные теги)
    final selectedTags = await fm.Navigator.of(context).push<List<String>>(
      fm.PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SearchScreen(
          activeTagFilters: _activeTagFilters,
          objectDistances: _objectDistances,
          preloadedPlacemarks:
              preloadedObjects, // Передаем предзагруженные объекты
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Анимация затемнения фона MapScreen
          return fm.FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        opaque: false,
      ),
    );

    // Проверяем, были ли выбраны теги
    if (selectedTags != null && selectedTags.isNotEmpty) {
      dev.log('Получены выбранные теги: $selectedTags');

      // Сохраняем активные фильтры
      _activeTagFilters = selectedTags;

      // Применяем фильтры к объектам на карте
      _mapObjectsManager?.setTagFilters(selectedTags);

      // Показываем кнопку очистки фильтров
      setState(() {
        _hasActiveFilters = true;
      });

      // Перемещаем камеру на начальную позицию
      _moveToInitialPosition();
    } else if (selectedTags != null) {
      // Если вернулся пустой список, очищаем фильтры
      dev.log('Получен пустой список тегов, очищаем фильтры');
      _mapObjectsManager?.clearFilters();

      // Очищаем активные фильтры
      _activeTagFilters = [];

      // Скрываем кнопку очистки фильтров
      setState(() {
        _hasActiveFilters = false;
      });
    }
  }

  // Перемещает камеру на начальную позицию
  void _moveToInitialPosition() {
    if (_mapWindow != null) {
      _mapWindow?.map.moveWithAnimation(
        CameraPosition(
          Point(latitude: 60.988094, longitude: 69.037551),
          zoom: 12.7,
          azimuth: 0.0,
          tilt: 17.0,
        ),
        const Animation(AnimationType.Smooth, duration: 1.0),
      );
      dev.log('Камера перемещена на начальную позицию');
    }
  }

  /// Получает расстояние до объекта по его ID
  double? getDistanceToObject(String objectId) {
    return _objectDistances[objectId];
  }
}
