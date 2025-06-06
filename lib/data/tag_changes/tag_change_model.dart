import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Модель данных для отслеживания изменений тегов объектов
class TagChangeData {
  final String id; // идентификатор записи изменения
  final List<DocumentReference> addedTags; // добавленные теги
  final List<DocumentReference> deletedTags; // удаленные теги
  final DocumentReference objectRef; // ссылка на объект
  final String objectId; // ID объекта (извлеченный из ссылки)
  final Timestamp timestamp; // время изменения
  final String userEmail; // email пользователя, внесшего изменения

  // Данные, которые будут загружены дополнительно
  String? objectName; // название объекта
  List<String> addedTagNames = []; // названия добавленных тегов
  List<String> deletedTagNames = []; // названия удаленных тегов

  /// Оригинальный DocumentSnapshot для пагинации
  final DocumentSnapshot? snapshot;

  TagChangeData({
    required this.id,
    required this.addedTags,
    required this.deletedTags,
    required this.objectRef,
    required this.objectId,
    required this.timestamp,
    required this.userEmail,
    this.objectName,
    this.snapshot,
  });

  /// Создает экземпляр TagChangeData из документа Firestore
  factory TagChangeData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Получаем ссылку на объект
    final objectRef = data['object_id'] as DocumentReference;

    // Получаем идентификатор объекта из ссылки
    final objectId = objectRef.id;

    // Получаем списки добавленных и удаленных тегов
    final addedTags = (data['added_tags'] as List?)
            ?.map((tag) => tag as DocumentReference)
            .toList() ??
        [];

    final deletedTags = (data['deleted_tags'] as List?)
            ?.map((tag) => tag as DocumentReference)
            .toList() ??
        [];

    return TagChangeData(
      id: doc.id,
      addedTags: addedTags,
      deletedTags: deletedTags,
      objectRef: objectRef,
      objectId: objectId,
      timestamp: data['timestamp'] as Timestamp,
      userEmail: data['user_email'] as String? ?? 'Неизвестный пользователь',
      snapshot: doc, // Сохраняем ссылку на оригинальный документ
    );
  }

  /// Возвращает отформатированную дату и время изменения
  String get formattedDate {
    final date = timestamp.toDate();
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return formatter.format(date);
  }
}
