import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель тега с поддержкой иерархической структуры
class TagData {
  final String id; // идентификатор тега
  final String name; // название тега на русском
  final DocumentReference? parent; // ссылка на родительский тег
  final List<DocumentReference> children; // список ссылок на дочерние теги

  // Поля для построения иерархии (заполняются после загрузки)
  TagData? parentTag; // родительский тег
  final List<TagData> childrenTags = []; // дочерние теги

  TagData({
    required this.id,
    required this.name,
    this.parent,
    required this.children,
  });

  /// Создает экземпляр TagData из документа Firestore
  factory TagData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TagData(
      id: doc.id,
      name: data['name'] ?? 'Неизвестный тег',
      parent: data['parent'] as DocumentReference?,
      children: List<DocumentReference>.from(data['children'] ?? []),
    );
  }

  @override
  String toString() {
    return 'TagData(id: $id, name: $name, childrenCount: ${children.length})';
  }
}
