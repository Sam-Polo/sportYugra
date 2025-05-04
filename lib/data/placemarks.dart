import 'package:yandex_maps_mapkit/mapkit.dart';
import '../models/placemark.dart';

final List<PlacemarkData> placemarks = [
  PlacemarkData(
    name: 'Лидер',
    description: 'Тренажерный зал/фитнес-клуб на Дзержинского',
    location: const Point(latitude: 61.007566, longitude: 69.020915),
  ),
  PlacemarkData(
    name: 'Лион',
    description: 'Тренажерный зал на улице Свободы',
    location: const Point(latitude: 60.969815, longitude: 69.057229),
  ),
  PlacemarkData(
    name: 'Югра-Атлетикс',
    description: 'Стадион',
    location: const Point(latitude: 60.979585, longitude: 69.034775),
  ),
  PlacemarkData(
    name: 'Биатлонный центр',
    description: 'Центр зимних видов спорта имени А. В. Филипенко',
    location: const Point(latitude: 60.984926, longitude: 69.03004),
  ),
  PlacemarkData(
    name: 'Ironfit',
    description: 'Тренажерный зал/фитнес-клуб на Ледовой',
    location: const Point(latitude: 60.976196, longitude: 69.017952),
  ),
];
