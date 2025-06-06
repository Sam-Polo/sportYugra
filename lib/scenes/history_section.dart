import 'dart:developer' as dev;
import 'package:flutter/material.dart' as fm;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' show Point;
import '../data/tag_changes/tag_change_model.dart';
import '../data/tag_changes/firestore_tag_changes.dart';
import '../data/placemarks/placemark_model.dart';
import '../widgets/object_details_sheet.dart';

/// Виджет для отображения истории изменений тегов объектов
class HistorySection extends fm.StatefulWidget {
  const HistorySection({super.key});

  @override
  fm.State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends fm.State<HistorySection> {
  final FirestoreTagChanges _firestoreTagChanges = FirestoreTagChanges();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<TagChangeData> _changes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _hasMoreChanges = false;

  // Количество записей, загружаемых за один раз
  final int _pageSize = 10;

  // Последний загруженный документ для пагинации
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadChanges();
  }

  // Загрузка первой порции истории изменений
  Future<void> _loadChanges() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final changes = await _firestoreTagChanges.getTagChanges(
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _changes = changes;
          _isLoading = false;

          // Сохраняем последний документ для пагинации
          if (changes.isNotEmpty) {
            _lastDocument = changes.last.snapshot;

            // Проверяем, есть ли еще записи
            _checkForMoreChanges();
          } else {
            _hasMoreChanges = false;
          }
        });
      }
    } catch (e) {
      dev.log('Ошибка при загрузке истории изменений: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Не удалось загрузить историю изменений';
          _isLoading = false;
        });
      }
    }
  }

  // Загрузка дополнительных записей
  Future<void> _loadMoreChanges() async {
    if (_isLoadingMore || _lastDocument == null) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final moreChanges = await _firestoreTagChanges.getTagChanges(
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      if (mounted) {
        setState(() {
          // Добавляем новые записи к существующим
          _changes.addAll(moreChanges);
          _isLoadingMore = false;

          // Обновляем последний документ для следующей загрузки
          if (moreChanges.isNotEmpty) {
            _lastDocument = moreChanges.last.snapshot;

            // Проверяем, есть ли еще записи
            _checkForMoreChanges();
          } else {
            _hasMoreChanges = false;
          }
        });
      }
    } catch (e) {
      dev.log('Ошибка при загрузке дополнительных изменений: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // Проверяет, есть ли еще записи для загрузки
  Future<void> _checkForMoreChanges() async {
    if (_lastDocument == null) {
      setState(() {
        _hasMoreChanges = false;
      });
      return;
    }

    try {
      final hasMore = await _firestoreTagChanges.hasMoreChanges(_lastDocument!);

      if (mounted) {
        setState(() {
          _hasMoreChanges = hasMore;
        });
      }
    } catch (e) {
      dev.log('Ошибка при проверке наличия дополнительных записей: $e');
    }
  }

  // Открывает детальную страницу объекта
  void _openObjectDetails(TagChangeData change) async {
    if (change.objectId.isEmpty) {
      dev.log('Нет ID объекта для открытия');
      return;
    }

    try {
      // Показываем индикатор загрузки
      fm.showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => fm.AlertDialog(
          backgroundColor: const fm.Color(0xFF0A1A2F),
          content: fm.Row(
            children: [
              fm.CircularProgressIndicator(
                valueColor:
                    fm.AlwaysStoppedAnimation<fm.Color>(fm.Color(0xFFFC4C4C)),
              ),
              fm.SizedBox(width: 16),
              fm.Text(
                'Загрузка объекта...',
                style: fm.TextStyle(color: fm.Colors.white),
              ),
            ],
          ),
        ),
      );

      // Загружаем данные объекта из Firestore
      final doc = await _firestore
          .collection('sportobjects')
          .doc(change.objectId)
          .get();

      // Закрываем диалог загрузки
      fm.Navigator.of(context, rootNavigator: true).pop();

      if (!doc.exists) {
        dev.log('Объект не найден: ${change.objectId}');
        if (mounted) {
          fm.ScaffoldMessenger.of(context).showSnackBar(
            fm.SnackBar(
              content: fm.Text('Объект не найден или был удалён'),
              backgroundColor: fm.Colors.red,
            ),
          );
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Получаем координаты
      final geoPoint = data['location'] as GeoPoint;

      // Создаем объект для отображения
      final placemark = PlacemarkData(
        id: doc.id,
        name: data['name'] as String,
        location: Point(
          latitude: geoPoint.latitude,
          longitude: geoPoint.longitude,
        ),
      );

      // Добавляем дополнительные данные, если они есть
      if (data.containsKey('description')) {
        placemark.description = data['description'] as String?;
      }

      if (data.containsKey('address')) {
        placemark.address = data['address'] as String?;
      }

      if (data.containsKey('phone')) {
        placemark.phone = data['phone'] as String?;
      }

      if (data.containsKey('photo-urls') && data['photo-urls'] is List) {
        placemark.photoUrls = List<String>.from(data['photo-urls'] as List);
      } else {
        placemark.photoUrls = [];
      }

      if (data.containsKey('equipmentDiversity')) {
        placemark.equipmentDiversity =
            (data['equipmentDiversity'] as num).toDouble();
      }

      // Показываем детали объекта
      if (mounted) {
        fm.showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: fm.Colors.transparent,
          builder: (context) => ObjectDetailsSheet(
            placemark: placemark,
          ),
        );
      }
    } catch (e) {
      dev.log('Ошибка при загрузке объекта: $e');
      if (mounted) {
        fm.ScaffoldMessenger.of(context).showSnackBar(
          fm.SnackBar(
            content: fm.Text('Ошибка при загрузке объекта'),
            backgroundColor: fm.Colors.red,
          ),
        );
      }
    }
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Container(
      decoration: const fm.BoxDecoration(
        color: fm.Color(0xFF0A1A2F), // темно-синий фон
        borderRadius: fm.BorderRadius.vertical(top: fm.Radius.circular(16)),
      ),
      child: fm.SafeArea(
        child: fm.Column(
          mainAxisSize: fm.MainAxisSize.min,
          crossAxisAlignment: fm.CrossAxisAlignment.start,
          children: [
            // Заголовок с кнопкой назад
            fm.Padding(
              padding: const fm.EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: fm.Row(
                children: [
                  fm.IconButton(
                    icon: const fm.Icon(fm.Icons.arrow_back,
                        color: fm.Colors.white),
                    onPressed: () => fm.Navigator.of(context).pop(),
                    tooltip: 'Назад',
                  ),
                  const fm.Text(
                    'Лента изменений',
                    style: fm.TextStyle(
                      color: fm.Colors.white,
                      fontSize: 20,
                      fontWeight: fm.FontWeight.bold,
                    ),
                  ),
                  const fm.Spacer(),
                  // Кнопка обновления
                  fm.IconButton(
                    icon:
                        const fm.Icon(fm.Icons.refresh, color: fm.Colors.white),
                    onPressed: _loadChanges,
                    tooltip: 'Обновить',
                  ),
                ],
              ),
            ),
            // Основное содержимое
            fm.Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // Построение основного содержимого в зависимости от состояния
  fm.Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingIndicator();
    }

    if (_errorMessage != null) {
      return _buildErrorMessage();
    }

    if (_changes.isEmpty) {
      return _buildEmptyState();
    }

    return _buildChangesList();
  }

  // Индикатор загрузки
  fm.Widget _buildLoadingIndicator() {
    return const fm.Center(
      child: fm.CircularProgressIndicator(
        valueColor: fm.AlwaysStoppedAnimation<fm.Color>(fm.Color(0xFFFC4C4C)),
      ),
    );
  }

  // Сообщение об ошибке
  fm.Widget _buildErrorMessage() {
    return fm.Center(
      child: fm.Column(
        mainAxisSize: fm.MainAxisSize.min,
        children: [
          const fm.Icon(
            fm.Icons.error_outline,
            color: fm.Color(0xFFFC4C4C),
            size: 48,
          ),
          const fm.SizedBox(height: 16),
          fm.Text(
            _errorMessage!,
            style: const fm.TextStyle(
              color: fm.Colors.white70,
              fontSize: 16,
            ),
            textAlign: fm.TextAlign.center,
          ),
          const fm.SizedBox(height: 24),
          fm.ElevatedButton(
            onPressed: _loadChanges,
            style: fm.ElevatedButton.styleFrom(
              backgroundColor: const fm.Color(0xFFFC4C4C),
              foregroundColor: fm.Colors.white,
            ),
            child: const fm.Text('Повторить'),
          ),
        ],
      ),
    );
  }

  // Состояние при отсутствии данных
  fm.Widget _buildEmptyState() {
    return fm.Center(
      child: fm.Column(
        mainAxisSize: fm.MainAxisSize.min,
        children: [
          const fm.Icon(
            fm.Icons.history,
            color: fm.Colors.white54,
            size: 48,
          ),
          const fm.SizedBox(height: 16),
          const fm.Text(
            'История изменений пуста',
            style: fm.TextStyle(
              color: fm.Colors.white70,
              fontSize: 16,
              fontWeight: fm.FontWeight.bold,
            ),
            textAlign: fm.TextAlign.center,
          ),
          const fm.SizedBox(height: 8),
          const fm.Text(
            'Здесь будут отображаться изменения, внесенные модераторами',
            style: fm.TextStyle(
              color: fm.Colors.white54,
              fontSize: 14,
            ),
            textAlign: fm.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Список изменений
  fm.Widget _buildChangesList() {
    return fm.ListView(
      padding: const fm.EdgeInsets.only(bottom: 16),
      children: [
        // Список изменений
        ...List.generate(_changes.length, (index) {
          final change = _changes[index];
          return _buildChangeItem(change);
        }),

        // Кнопка "Загрузить еще" или индикатор загрузки
        if (_isLoadingMore)
          fm.Padding(
            padding: const fm.EdgeInsets.all(16.0),
            child: fm.Center(
              child: fm.CircularProgressIndicator(
                valueColor: fm.AlwaysStoppedAnimation<fm.Color>(
                  fm.Color(0xFFFC4C4C),
                ),
              ),
            ),
          )
        else if (_hasMoreChanges)
          fm.Padding(
            padding: const fm.EdgeInsets.all(16.0),
            child: fm.Center(
              child: fm.ElevatedButton(
                onPressed: _loadMoreChanges,
                style: fm.ElevatedButton.styleFrom(
                  backgroundColor: fm.Colors.white.withOpacity(0.1),
                  foregroundColor: fm.Colors.white,
                ),
                child: const fm.Text('Загрузить еще'),
              ),
            ),
          ),
      ],
    );
  }

  // Элемент списка изменений
  fm.Widget _buildChangeItem(TagChangeData change) {
    return fm.Card(
      margin: const fm.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: fm.Colors.white.withOpacity(0.05),
      shape: fm.RoundedRectangleBorder(
        borderRadius: fm.BorderRadius.circular(12),
      ),
      child: fm.Padding(
        padding: const fm.EdgeInsets.all(16),
        child: fm.Column(
          crossAxisAlignment: fm.CrossAxisAlignment.start,
          children: [
            // Заголовок с датой
            fm.Row(
              children: [
                // Иконка с датой
                fm.Icon(
                  fm.Icons.calendar_today,
                  color: fm.Colors.white70,
                  size: 16,
                ),
                fm.SizedBox(width: 8),
                fm.Text(
                  change.formattedDate,
                  style: fm.TextStyle(
                    color: fm.Colors.white70,
                    fontSize: 14,
                  ),
                ),
                // Удалено отображение модератора и его иконки
              ],
            ),
            fm.SizedBox(height: 12),

            // Название объекта с возможностью нажатия
            fm.InkWell(
              onTap: () => _openObjectDetails(change),
              borderRadius: fm.BorderRadius.circular(8),
              child: fm.Padding(
                padding: const fm.EdgeInsets.symmetric(vertical: 4),
                child: fm.Row(
                  children: [
                    fm.Icon(
                      fm.Icons.place,
                      color: fm.Color(0xFFFC4C4C),
                      size: 18,
                    ),
                    fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Text(
                        change.objectName ?? 'Неизвестный объект',
                        style: fm.TextStyle(
                          color: fm.Colors.white,
                          fontSize: 16,
                          fontWeight: fm.FontWeight.bold,
                        ),
                      ),
                    ),
                    // Стрелка, указывающая на возможность нажатия
                    fm.Icon(
                      fm.Icons.arrow_forward_ios,
                      color: fm.Colors.white.withOpacity(0.5),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            fm.SizedBox(height: 16),

            // Добавленные теги
            if (change.addedTagNames.isNotEmpty) ...[
              fm.Row(
                children: [
                  fm.Icon(
                    fm.Icons.add_circle_outline,
                    color: fm.Colors.green,
                    size: 16,
                  ),
                  fm.SizedBox(width: 8),
                  fm.Text(
                    'Добавлены',
                    style: fm.TextStyle(
                      color: fm.Colors.green,
                      fontSize: 14,
                      fontWeight: fm.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              fm.SizedBox(height: 4),
              fm.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: change.addedTagNames
                    .map((tag) => _buildTagChip(
                          tag,
                          fm.Colors.green.withOpacity(0.8),
                        ))
                    .toList(),
              ),
              fm.SizedBox(height: 12),
            ],

            // Удаленные теги
            if (change.deletedTagNames.isNotEmpty) ...[
              fm.Row(
                children: [
                  fm.Icon(
                    fm.Icons.remove_circle_outline,
                    color: fm.Colors.red,
                    size: 16,
                  ),
                  fm.SizedBox(width: 8),
                  fm.Text(
                    'Удалены',
                    style: fm.TextStyle(
                      color: fm.Colors.red,
                      fontSize: 14,
                      fontWeight: fm.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              fm.SizedBox(height: 4),
              fm.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: change.deletedTagNames
                    .map((tag) => _buildTagChip(
                          tag,
                          fm.Colors.red.withOpacity(0.8),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Чип для отображения тега
  fm.Widget _buildTagChip(String tagName, fm.Color color) {
    return fm.Container(
      padding: const fm.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: fm.BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: fm.BorderRadius.circular(16),
        border: fm.Border.all(color: color.withOpacity(0.5)),
      ),
      child: fm.Text(
        tagName,
        style: fm.TextStyle(
          color: fm.Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}
