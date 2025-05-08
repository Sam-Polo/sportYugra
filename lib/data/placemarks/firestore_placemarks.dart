import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'placemark_model.dart';

class FirestorePlacemarks {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // получение всех спортивных объектов из Firestore
  Future<List<PlacemarkData>> getSportObjects() async {
    try {
      // Получаем снимок коллекции
      final QuerySnapshot snapshot =
          await _firestore.collection('sportobjects').get();

      // Преобразуем документы в модели
      final List<PlacemarkData> placemarks = [];

      for (final doc in snapshot.docs) {
        try {
          final PlacemarkData placemark = PlacemarkData.fromFirestore(doc);
          placemarks.add(placemark);
        } catch (e) {
          print('Ошибка при обработке документа ${doc.id}: $e');
          // Пропускаем проблемный документ и продолжаем
        }
      }

      return placemarks;
    } catch (e) {
      // Логирование ошибки
      print('Ошибка при получении данных из Firestore: $e');
      return [];
    }
  }
}
