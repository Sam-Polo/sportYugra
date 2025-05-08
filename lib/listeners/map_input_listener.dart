import 'dart:developer' as dev;
import 'package:yandex_maps_mapkit/mapkit.dart';

final class MapInputListenerImpl implements MapInputListener {
  // Пока просто логируем, без внешних колбэков

  const MapInputListenerImpl();

  @override
  void onMapTap(Map map, Point point) {
    // Логируем касание на карте
    dev.log('Map tapped at coordinates: ${point.latitude}, ${point.longitude}');
  }

  @override
  void onMapLongTap(Map map, Point point) {
    // Логируем долгое нажатие на карте
    dev.log(
        'Map long tapped at coordinates: ${point.latitude}, ${point.longitude}');
  }
}
