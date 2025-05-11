import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/image.dart';
import '../camera/camera_manager.dart';
import '../permissions/permission_manager.dart';
import '../widgets/map_control_button.dart';
import '../listeners/map_object_tap_listener.dart';
import '../data/placemarks/placemark_model.dart';
import '../data/placemarks/firestore_placemarks.dart';
import '../map_objects/map_objects_manager.dart';

class MapScreen extends fm.StatefulWidget {
  const MapScreen({super.key});

  @override
  fm.State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends fm.State<MapScreen>
    with fm.WidgetsBindingObserver
    implements UserLocationObjectListener {
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
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
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
        _showPlacemarkInfo(userData, point);
        return true; // прекращаем обработку события
      }
    }
    return false; // продолжаем обработку события
  }

  // Показывает информацию о плейсмарке
  void _showPlacemarkInfo(PlacemarkData placemark, Point point) {
    dev.log(
        'Показываем информацию о метке: ${placemark.name}, координаты: ${point.latitude}, ${point.longitude}');

    // Показываем диалог с информацией о метке
    if (mounted) {
      fm.ScaffoldMessenger.of(context).showSnackBar(
        fm.SnackBar(
          content: fm.Text('Выбран объект: ${placemark.name}'),
          duration: const Duration(seconds: 2),
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

      // Попытка переместить камеру после загрузки и получения местоположения
      _tryMoveCameraAfterLoadAndLocation();
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
            left: 0,
            right: 0,
            top: 0,
            child: const _MapSearchBar(),
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
  void onObjectUpdated(UserLocationView view, ObjectEvent event) {}

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
}

class _MapSearchBar extends fm.StatelessWidget {
  const _MapSearchBar();

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.SafeArea(
      child: fm.Container(
        margin: const fm.EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
        ),
        padding: const fm.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: fm.BoxDecoration(
          color: fm.Colors.black.withOpacity(0.7),
          borderRadius: fm.BorderRadius.circular(12),
        ),
        child: fm.Row(
          children: [
            const fm.Icon(
              fm.Icons.search,
              color: fm.Colors.grey,
              size: 24,
            ),
            const fm.SizedBox(width: 8),
            fm.Text(
              'Поиск',
              style: fm.TextStyle(
                color: fm.Colors.grey,
                fontSize: 18,
                fontWeight: fm.FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
