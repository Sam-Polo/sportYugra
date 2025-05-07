// map screen:
import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart' show rootBundle;
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/image.dart';
import '../data/placemarks.dart';

class MapScreen extends fm.StatefulWidget {
  const MapScreen({super.key});

  @override
  fm.State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends fm.State<MapScreen>
    with fm.WidgetsBindingObserver {
  MapWindow? _mapWindow;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    fm.WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    print('MapKit onStart');
    mapkit.onStart();
  }

  @override
  void dispose() {
    fm.WidgetsBinding.instance.removeObserver(this);
    print('MapKit onStop');
    mapkit.onStop();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
      print('Map style loaded');
      if (_mapWindow != null) {
        _mapWindow?.map.setMapStyle(_mapStyle!);
        print('Map style applied');
      }
    } catch (e) {
      print('Error loading map style: $e');
    }
  }

  void _addPlacemarks() {
    if (_mapWindow == null) return;

    for (final placemark in placemarks) {
      final mapPlacemark = _mapWindow!.map.mapObjects.addPlacemark()
        ..geometry = placemark.location
        ..setText(placemark.name)
        ..setTextStyle(
          const TextStyle(
            size: 12.0,
            color: fm.Colors.black,
            outlineColor: fm.Colors.white,
            placement: TextStylePlacement.Right,
            offset: 5.0,
          ),
        )
        ..setIcon(
          ImageProvider.fromImageProvider(
            const fm.AssetImage("assets/images/Yandex_Maps_icon.png"),
          ),
        )
        ..setIconStyle(
          const IconStyle(
            scale: 0.1,
          ),
        );
    }
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
      body: fm.Stack(
        children: [
          YandexMap(
            onMapCreated: (mapWindow) {
              print('Map created: $mapWindow');
              _mapWindow = mapWindow;

              if (_mapStyle != null) {
                _mapWindow?.map.setMapStyle(_mapStyle!);
                print('Map style applied');
              }

              try {
                _mapWindow?.map.move(
                  CameraPosition(
                    Point(latitude: 60.988094, longitude: 69.037551),
                    zoom: 12.7,
                    azimuth: 0.0,
                    tilt: 17.0,
                  ),
                );
                print('Camera placed');

                // Добавляем метки после инициализации карты
                _addPlacemarks();
              } catch (e) {
                print('Error moving camera: $e');
              }
            },
          ),
          fm.Positioned(
            right: 16,
            bottom: 16,
            child: fm.Material(
              color: fm.Colors.black,
              borderRadius: fm.BorderRadius.circular(8),
              elevation: 4,
              child: fm.InkWell(
                borderRadius: fm.BorderRadius.circular(8),
                onTap: () {
                  // TODO: Добавить функционал возврата к своему местоположению
                },
                child: fm.Container(
                  width: 48,
                  height: 48,
                  child: fm.Center(
                    child: fm.Text(
                      "Я",
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 24,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
