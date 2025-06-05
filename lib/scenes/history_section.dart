import 'dart:developer' as dev;
import 'package:flutter/material.dart' as fm;
import '../data/tag_changes/tag_change_model.dart';
import '../data/tag_changes/firestore_tag_changes.dart';

/// Виджет для отображения истории изменений тегов объектов
class HistorySection extends fm.StatefulWidget {
  const HistorySection({super.key});

  @override
  fm.State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends fm.State<HistorySection> {
  final FirestoreTagChanges _firestoreTagChanges = FirestoreTagChanges();
  List<TagChangeData> _changes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Максимальное количество загружаемых записей
  final int _limit = 50;

  @override
  void initState() {
    super.initState();
    _loadChanges();
  }

  // Загрузка истории изменений
  Future<void> _loadChanges() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final changes = await _firestoreTagChanges.getTagChanges(limit: _limit);

      if (mounted) {
        setState(() {
          _changes = changes;
          _isLoading = false;
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

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.SafeArea(
      child: fm.Container(
        decoration: const fm.BoxDecoration(
          color: fm.Color(0xFF0A1A2F), // темно-синий фон
          borderRadius: fm.BorderRadius.vertical(top: fm.Radius.circular(16)),
        ),
        child: fm.Column(
          mainAxisSize: fm.MainAxisSize.min,
          crossAxisAlignment: fm.CrossAxisAlignment.start,
          children: [
            // Заголовок с кнопкой назад
            fm.Padding(
              padding: const fm.EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: fm.Row(
                children: [
                  fm.IconButton(
                    icon: const fm.Icon(fm.Icons.arrow_back,
                        color: fm.Colors.white),
                    onPressed: () => fm.Navigator.of(context).pop(),
                    tooltip: 'Назад',
                  ),
                  const fm.Text(
                    'История изменений',
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
    return fm.ListView.builder(
      padding: const fm.EdgeInsets.only(bottom: 16),
      itemCount: _changes.length,
      itemBuilder: (context, index) {
        final change = _changes[index];
        return _buildChangeItem(change);
      },
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
            // Заголовок с датой и именем объекта
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
                fm.Spacer(),
                // Модератор
                fm.Row(
                  mainAxisSize: fm.MainAxisSize.min,
                  children: [
                    fm.Icon(
                      fm.Icons.person,
                      color: fm.Colors.white70,
                      size: 16,
                    ),
                    fm.SizedBox(width: 8),
                    fm.Text(
                      change.userEmail.length > 20
                          ? '${change.userEmail.substring(0, 18)}...'
                          : change.userEmail,
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 13,
                        fontWeight: fm.FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            fm.SizedBox(height: 12),

            // Название объекта
            fm.Row(
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
              ],
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
