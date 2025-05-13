// lib\scenes\search_screen.dart
import 'package:flutter/material.dart' as fm;
import 'dart:developer' as dev;
import 'map_screen.dart'; // <- Импортируем MapScreen для доступа к MapSearchBar
import '../data/tags/firestore_tags.dart';
import '../data/tags/tag_model.dart';

class SearchScreen extends fm.StatefulWidget {
  const SearchScreen({super.key});

  @override
  fm.State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends fm.State<SearchScreen> {
  // Контроллер и FocusNode для управления текстовым полем
  late fm.TextEditingController _searchController;
  late fm.FocusNode _searchFocusNode;

  // Флаг для отслеживания, установлен ли фокус
  bool _focusRequested = false;

  // Сервис для работы с тегами
  final _firestoreTags = FirestoreTags();

  // Состояние загрузки и данные тегов
  bool _isLoading = false;
  List<TagData> _rootTags = [];
  String _tagsHierarchyText = '';

  @override
  void initState() {
    super.initState();
    _searchController = fm.TextEditingController();
    _searchFocusNode = fm.FocusNode();

    // увеличиваем задержку до 600мс (равна длительности анимации перехода)
    fm.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusRequested) {
        _focusRequested = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _searchFocusNode.requestFocus();
            dev.log('Focus requested after hero animation');
          }
        });
      }
    });

    // Загружаем теги
    _loadTags();
  }

  /// Загружает теги из Firestore
  Future<void> _loadTags() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Загружаем все теги
      final rootTags = await _firestoreTags.loadAllTags();

      // Получаем текстовое представление иерархии
      final hierarchyText = _firestoreTags.getTagsHierarchyString();

      if (mounted) {
        setState(() {
          _rootTags = rootTags;
          _tagsHierarchyText = hierarchyText;
          _isLoading = false;
        });
      }
    } catch (e) {
      dev.log('Ошибка при загрузке тегов: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Освобождаем ресурсы
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
      backgroundColor: fm.Colors.black, // Черный фон
      body: fm.Column(
        // <- Используем Column для размещения SearchBar сверху
        children: [
          fm.SafeArea(
            child: fm.Padding(
              padding: const fm.EdgeInsets.only(
                  left: 16, right: 16, top: 2), // <- Внешние отступы
              child: fm.Hero(
                tag: 'searchBarHero', // <- Hero с тем же тегом
                // Создаем виджет, который способен сохранять состояние во время анимации Hero
                child: fm.Material(
                  color: fm.Colors.transparent,
                  child: MapSearchBar(
                    isButton: false, // <- Режим поля ввода вместо isTextField
                    controller: _searchController, // <- Передаем контроллер
                    focusNode: _searchFocusNode, // <- Передаем FocusNode
                    autoFocus:
                        false, // <- Важно! Отключаем автофокус, используем отложенный запрос фокуса
                    onChanged: (text) {
                      // Обрабатываем изменение текста
                      setState(() {
                        // Здесь можем обновить результаты поиска при вводе
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          // Область для отображения иерархии тегов
          fm.Expanded(
            child: _isLoading
                ? const fm.Center(
                    child: fm.CircularProgressIndicator(
                      color: fm.Colors.white,
                    ),
                  )
                : _buildTagsHierarchyView(),
          ),
        ],
      ),
    );
  }

  /// Строит представление иерархии тегов
  fm.Widget _buildTagsHierarchyView() {
    if (_rootTags.isEmpty) {
      return const fm.Center(
        child: fm.Text(
          'Теги не найдены',
          style: fm.TextStyle(color: fm.Colors.white54),
        ),
      );
    }

    return fm.Padding(
      padding: const fm.EdgeInsets.all(16.0),
      child: fm.Column(
        crossAxisAlignment: fm.CrossAxisAlignment.start,
        children: [
          const fm.Text(
            'Иерархия тегов:',
            style: fm.TextStyle(
              color: fm.Colors.white,
              fontSize: 18,
              fontWeight: fm.FontWeight.bold,
            ),
          ),
          const fm.SizedBox(height: 16),
          fm.Expanded(
            child: fm.Container(
              padding: const fm.EdgeInsets.all(12),
              decoration: fm.BoxDecoration(
                color: fm.Colors.white10,
                borderRadius: fm.BorderRadius.circular(8),
              ),
              child: fm.SingleChildScrollView(
                child: fm.Text(
                  _tagsHierarchyText,
                  style: const fm.TextStyle(
                    color: fm.Colors.white,
                    fontFamily: 'monospace',
                    height: 1.5,
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
