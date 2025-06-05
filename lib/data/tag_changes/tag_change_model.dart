import 'package:cloud_firestore/cloud_firestore.dart';

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

  TagChangeData({
    required this.id,
    required this.addedTags,
    required this.deletedTags,
    required this.objectRef,
    required this.timestamp,
    required this.userEmail,
    this.objectName,
  }) : objectId = objectRef.id;

  /// Создает экземпляр TagChangeData из документа Firestore
  factory TagChangeData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TagChangeData(
      id: doc.id,
      addedTags: List<DocumentReference>.from(data['added_tags'] ?? []),
      deletedTags: List<DocumentReference>.from(data['deleted_tags'] ?? []),
      objectRef: data['object_id'] as DocumentReference,
      timestamp: data['timestamp'] as Timestamp,
      userEmail: data['user_email'] as String? ?? 'Неизвестный пользователь',
    );
  }

  /// Возвращает отформатированную дату и время изменения
  String get formattedDate {
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
