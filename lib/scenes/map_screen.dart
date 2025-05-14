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
import '../camera/camera_manager.dart';
import '../scenes/search_screen.dart';
import '../permissions/permission_manager.dart';
import '../widgets/map_control_button.dart';
import '../listeners/map_object_tap_listener.dart';
import '../data/placemarks/placemark_model.dart';
import '../data/placemarks/firestore_placemarks.dart';
import '../map_objects/map_objects_manager.dart';
import '../widgets/object_details_sheet.dart';
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

  /// Строит содержимое MapSearchBar в режиме кнопки (внутренняя часть)
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
  // Флаг для включения/отключения автоматического перемещения камеры к пользователю после загрузки и определения местоположения
  final bool _enableAutoCameraMove = false; // установите false для отключения

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

  // Флаг загрузки данных
  bool _isLoading = false;
  bool _placemarksLoaded = false; // добавил флаг загрузки плейсмарков
  bool _locationInitialized =
      false; // добавил флаг инициализации местоположения

  // Порог зума, ниже которого названия меток будут скрыты
  // отредактируй это значение, чтобы изменить порог
  final double _textVisibilityZoomThreshold = 14.0;

  // Текущее местоположение пользователя
  Point? _userLocation;

  // Словарь для хранения расстояний до объектов (ключ - идентификатор объекта)
  final _objectDistances = HashMap<String, double>();

  // Флаг для отображения кнопки "Очистить фильтры"
  bool _hasActiveFilters = false;

  @override
  void initState() {
    super.initState();
    fm.WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _requestLocationPermission();

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

      dev.log(
          'Расстояние до объекта ${placemark.name} обновлено: ${distanceInMeters.toStringAsFixed(1)} м (${userLocation != null ? "от местоположения пользователя" : "от камеры"})');
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

    dev.log('Расстояния до всех объектов обновлены');
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

      // Вместо SnackBar открываем модальное окно с детальной информацией
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
  }

  // Загружает объекты из Firestore и добавляет их на карту
  Future<void> _loadPlacemarksFromFirestore() async {
    if (_mapWindow == null || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Инициализируем менеджер объектов карты, если еще не сделано
      _mapObjectsManager ??= MapObjectsManager(
        _mapWindow!,
        onMapObjectTap: _onMapObjectTapped,
      );

      // Очищаем текущие объекты, если они есть
      _mapObjectsManager!.clear();

      // Загружаем спортивные объекты из Firestore
      final placemarks = await _firestorePlacemarks.getSportObjects();

      // Добавляем загруженные объекты на карту
      _mapObjectsManager!.addPlacemarks(placemarks);

      dev.log(
          'Плейсмарки из Firestore добавлены на карту: ${placemarks.length}');

      // Отмечаем, что плейсмарки загружены
      _placemarksLoaded = true;

      // Обновляем расстояния до всех объектов
      _updateAllDistances();

      // Попытка переместить камеру после загрузки и получения местоположения
      _tryMoveCameraAfterLoadAndLocation();

      // После загрузки и добавления плейсмарков, обновляем их видимость текста
      // в зависимости от текущего зума
      if (_mapWindow != null) {
        _updatePlacemarkTextVisibility(_mapWindow!.map.cameraPosition.zoom);
      }
    } catch (e) {
      dev.log('Ошибка загрузки плейсмарков из Firestore: $e');

      if (mounted) {
        fm.ScaffoldMessenger.of(context).showSnackBar(
          fm.SnackBar(
            content: fm.Text('Не удалось загрузить объекты'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    dev.log(
        '[MapScreenState] _updatePlacemarkTextVisibility called with zoom: $currentZoom, coords: ${(_mapWindow?.map.cameraPosition.target.latitude)?.toStringAsFixed(4)}, ${(_mapWindow?.map.cameraPosition.target.longitude)?.toStringAsFixed(4)}'); // лог вызова метода с координатами
    // если менеджер объектов не инициализирован, выходим
    if (_mapObjectsManager == null) return;

    // определяем, нужно ли показывать текст на текущем зуме
    final bool showText = currentZoom >= _textVisibilityZoomThreshold;

    // перебираем все добавленные плейсмарки и обновляем их видимость текста через менеджер объектов
    _mapObjectsManager?.forEachPlacemark((placemarkObject, placemarkId) {
      _mapObjectsManager?.setPlacemarkTextVisibility(placemarkId, showText);
    });
    // dev.log('Text visibility updated for zoom: $currentZoom, showText: $showText'); // для отладки
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
                  onPressed: _clearFilters,
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
    if (view.pin.geometry != null) {
      _userLocation = view.pin.geometry;
      dev.log(
          'Местоположение пользователя обновлено: ${_userLocation?.latitude}, ${_userLocation?.longitude}');

      // Обновляем расстояния до всех объектов при изменении местоположения
      _updateAllDistances();
    }
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

  // Метод для очистки фильтров
  void _clearFilters() {
    _mapObjectsManager?.clearFilters();
    setState(() {
      _hasActiveFilters = false;
    });
    dev.log('Фильтры очищены');
  }

  // Метод для открытия экрана поиска
  void _openSearchScreen(fm.BuildContext context) async {
    dev.log('Search bar tapped, initiating transition...');

    // Открываем экран поиска и ждем результат (выбранные теги)
    final selectedTags = await fm.Navigator.of(context).push<List<String>>(
      fm.PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SearchScreen(),
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

      // Применяем фильтры к объектам на карте
      _mapObjectsManager?.setTagFilters(selectedTags);

      // Показываем кнопку очистки фильтров
      setState(() {
        _hasActiveFilters = true;
      });

      // Перемещаем камеру на начальную позицию
      _moveToInitialPosition();
    } else if (selectedTags != null && selectedTags.isEmpty) {
      // Если вернулся пустой список, очищаем фильтры
      dev.log('Получен пустой список тегов, очищаем фильтры');
      _mapObjectsManager?.clearFilters();

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
}
