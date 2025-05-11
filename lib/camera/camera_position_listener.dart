import 'package:yandex_maps_mapkit/mapkit.dart';
import 'dart:developer' as dev;

class CameraPositionListenerImpl implements MapCameraListener {
  final void Function(
    Map map,
    CameraPosition cameraPosition,
    CameraUpdateReason cameraUpdateReason,
    bool isFinished,
  ) _onCameraPositionChanged;

  const CameraPositionListenerImpl(this._onCameraPositionChanged);

  @override
  void onCameraPositionChanged(
    Map map,
    CameraPosition cameraPosition,
    CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    dev.log(
        '[CameraPositionListenerImpl] onCameraPositionChanged called, zoom: ${cameraPosition.zoom}, finished: $finished');
    _onCameraPositionChanged(map, cameraPosition, cameraUpdateReason, finished);
  }
}
