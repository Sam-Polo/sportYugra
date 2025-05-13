// lib\scenes\search_screen.dart
import 'package:flutter/material.dart' as fm;
import 'dart:developer' as dev;
import 'map_screen.dart'; // <- Импортируем MapScreen для доступа к MapSearchBar

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
          // TODO: Add search results area below the search bar
          fm.Expanded(
            // <- Растягиваем оставшееся пространство
            child: fm.Center(
              child: _searchController.text.isEmpty
                  ? const fm.Text(
                      'Введите запрос для поиска',
                      style: fm.TextStyle(color: fm.Colors.white54),
                    )
                  : fm.Text(
                      'Поиск по запросу: ${_searchController.text}',
                      style: const fm.TextStyle(color: fm.Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
