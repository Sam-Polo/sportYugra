import 'dart:developer' as dev;
import 'package:yandex_maps_mapkit/mapkit.dart';

final class MapObjectTapListenerImpl implements MapObjectTapListener {
  final bool Function(MapObject, Point) onMapObjectTapped;

  const MapObjectTapListenerImpl({required this.onMapObjectTapped});

  @override
  bool onMapObjectTap(MapObject mapObject, Point point) {
    // логируем нажатие на объект карты
    dev.log(
        'Map object tapped: ${mapObject.runtimeType}, at coordinates: ${point.latitude}, ${point.longitude}');
    // Вызываем внешний колбэк и возвращаем его результат
    return onMapObjectTapped(mapObject, point);
  }
}
