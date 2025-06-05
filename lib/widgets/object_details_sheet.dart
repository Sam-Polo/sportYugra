import 'package:flutter/material.dart' as fm;
import 'dart:developer' as dev;
import '../data/placemarks/placemark_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/tags/firestore_tags.dart';
import '../data/tags/tag_model.dart';

/// Виджет для отображения детальной страницы объекта с фотогалереей
class ObjectDetailsSheet extends fm.StatefulWidget {
  final PlacemarkData placemark;
  final double? distance; // Расстояние до объекта

  const ObjectDetailsSheet({
    super.key,
    required this.placemark,
    this.distance, // Опциональный параметр расстояния
  });

  @override
  fm.State<ObjectDetailsSheet> createState() => _ObjectDetailsSheetState();
}

class _ObjectDetailsSheetState extends fm.State<ObjectDetailsSheet>
    with fm.SingleTickerProviderStateMixin {
  late fm.TabController _tabController;
  final fm.PageController _photoPageController = fm.PageController();
  int _currentPhotoIndex = 0;

  // Список обработчиков предзагрузки изображений для возможности отмены
  final List<fm.ImageStreamListener> _imagePrecacheHandlers = [];

  // Для работы с тегами
  final _firestoreTags = FirestoreTags();
  List<TagData> _objectTags = [];
  bool _tagsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = fm.TabController(length: 2, vsync: this);

    // Предзагружаем все фото объекта при открытии страницы
    _precacheAllImages();

    // Загружаем теги объекта
    _loadObjectTags();
  }

  /// Предзагрузка всех изображений для галереи
  void _precacheAllImages() {
    if (widget.placemark.photoUrls == null ||
        widget.placemark.photoUrls!.isEmpty) {
      return;
    }

    dev.log(
        'Начинаем предзагрузку ${widget.placemark.photoUrls!.length} изображений');

    for (final photoUrl in widget.placemark.photoUrls!) {
      final imageProvider = fm.NetworkImage(photoUrl);

      // Создаем слушателя загрузки изображения
      final imageStreamListener = fm.ImageStreamListener(
        (fm.ImageInfo info, bool syncCall) {
          // Изображение загружено успешно
          if (mounted) {
            dev.log('Предзагружено изображение: $photoUrl');
          }
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          // Ошибка загрузки изображения
          if (mounted) {
            dev.log('Ошибка предзагрузки изображения: $photoUrl - $exception');
          }
        },
      );

      // Начинаем загрузку изображения и добавляем слушателя
      final imageStream = imageProvider.resolve(const fm.ImageConfiguration());
      imageStream.addListener(imageStreamListener);

      // Сохраняем слушателя для последующей отмены
      _imagePrecacheHandlers.add(imageStreamListener);
    }
  }

  @override
  void dispose() {
    // Отменяем все незавершенные загрузки изображений
    _cancelImagePreloading();
    _tabController.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  /// Отменяет все незавершенные предзагрузки изображений
  void _cancelImagePreloading() {
    dev.log('Отмена всех незавершенных загрузок изображений');

    if (widget.placemark.photoUrls == null) return;

    for (int i = 0;
        i < widget.placemark.photoUrls!.length &&
            i < _imagePrecacheHandlers.length;
        i++) {
      try {
        final imageProvider = fm.NetworkImage(widget.placemark.photoUrls![i]);
        final imageStream =
            imageProvider.resolve(const fm.ImageConfiguration());
        imageStream.removeListener(_imagePrecacheHandlers[i]);
      } catch (e) {
        dev.log('Ошибка при отмене загрузки изображения: $e');
      }
    }

    _imagePrecacheHandlers.clear();
  }

  /// Форматирует телефонный номер в удобный для чтения формат
  String _formatPhoneNumber(String phone) {
    // Убираем всё, кроме цифр
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

    // Если номер начинается с 8 или 7, преобразуем в международный формат +7
    var formattedNumber = digitsOnly;
    if (formattedNumber.length == 11) {
      if (formattedNumber.startsWith('8') || formattedNumber.startsWith('7')) {
        formattedNumber = '7${formattedNumber.substring(1)}';
      }
    }

    // Если номер неправильной длины, возвращаем без форматирования
    if (formattedNumber.length != 11) {
      return phone; // Возвращаем оригинал, если не стандартный формат
    }

    // Форматируем как +7 (XXX) XXX-XX-XX
    return '+${formattedNumber.substring(0, 1)} (${formattedNumber.substring(1, 4)}) ${formattedNumber.substring(4, 7)}-${formattedNumber.substring(7, 9)}-${formattedNumber.substring(9)}';
  }

  /// Форматирует расстояние для отображения
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      // Если меньше километра, показываем в метрах
      return '${distanceInMeters.round()} м';
    } else {
      // Если больше километра, показываем в километрах с одним знаком после запятой
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} км';
    }
  }

  /// Загружает теги для объекта
  Future<void> _loadObjectTags() async {
    if (!mounted) return;

    setState(() {
      _tagsLoading = true;
    });

    try {
      // Используем ID объекта для загрузки тегов
      final String objectId = widget.placemark.id;

      if (objectId.isEmpty) {
        dev.log('Невозможно загрузить теги: ID объекта пуст');
        return;
      }

      final tags = await _firestoreTags.loadTagsForObject(objectId);
      dev.log('Загружено ${tags.length} тегов для объекта $objectId');

      if (mounted) {
        setState(() {
          _objectTags = tags;
          _tagsLoading = false;
        });
      }
    } catch (e) {
      dev.log('Ошибка при загрузке тегов объекта: $e');
      if (mounted) {
        setState(() {
          _tagsLoading = false;
        });
      }
    }
  }

  /// Строит вкладку с тегами
  fm.Widget _buildTagsTab() {
    if (_tagsLoading) {
      return const fm.Center(
        child: fm.CircularProgressIndicator(),
      );
    }

    if (_objectTags.isEmpty) {
      return const fm.Center(
        child: fm.Text('Теги не найдены'),
      );
    }

    return fm.SingleChildScrollView(
      padding: const fm.EdgeInsets.all(16.0),
      child: fm.Column(
        crossAxisAlignment: fm.CrossAxisAlignment.start,
        children: [
          // Заголовок иерархии тегов
          const fm.Text(
            'Теги объекта:',
            style: fm.TextStyle(
              fontSize: 18,
              fontWeight: fm.FontWeight.bold,
            ),
          ),
          const fm.SizedBox(height: 16),

          // Отображаем иерархию тегов
          _buildTagsHierarchy(),
        ],
      ),
    );
  }

  /// Строит иерархическое представление тегов объекта
  fm.Widget _buildTagsHierarchy() {
    // Группируем теги по их уровням в иерархии
    final Map<String, List<TagData>> tagsByParent = {};

    // Проверяем, есть ли у тегов родительские теги, которых нет в списке тегов объекта
    for (final tag in _objectTags) {
      if (tag.parent != null) {
        final parentId = tag.parent!.id;
        final hasParentTag = _objectTags.any((t) => t.id == parentId);

        if (!hasParentTag) {
          // Проверяем случай, когда у тега есть родитель, но родительского тега нет в списке тегов объекта
          dev.log(
              'ПРЕДУПРЕЖДЕНИЕ: У тега ${tag.id} (${tag.name}) есть родитель $parentId, но родительский тег не найден в тегах объекта');
        }
      }
    }

    // Сначала находим все корневые теги (без родителя)
    final rootTags = _objectTags.where((tag) => tag.parent == null).toList();

    // Если корневых тегов нет, возвращаем сообщение
    if (rootTags.isEmpty) {
      dev.log('ВНИМАНИЕ: Не найдены корневые теги у объекта');
      return const fm.Text(
          'Не удалось построить иерархию тегов: не найдены корневые теги');
    }

    // Группируем все остальные теги по parentId
    for (final tag in _objectTags) {
      if (tag.parent != null) {
        final parentId = tag.parent!.id;
        tagsByParent.putIfAbsent(parentId, () => []).add(tag);
      }
    }

    // Строим дерево, начиная с корневых тегов
    return fm.Column(
      crossAxisAlignment: fm.CrossAxisAlignment.start,
      children: rootTags
          .map((rootTag) => _buildTagHierarchyItem(rootTag, tagsByParent, 0))
          .toList(),
    );
  }

  /// Рекурсивно строит элемент иерархии тегов и его дочерние теги
  fm.Widget _buildTagHierarchyItem(
      TagData tag, Map<String, List<TagData>> tagsByParent, int level) {
    // Получаем дочерние теги для текущего тега, если они есть
    final childTags = tagsByParent[tag.id] ?? [];
    final bool hasChildren = childTags.isNotEmpty;

    // Проверяем согласованность данных
    if (hasChildren) {
      for (final childTag in childTags) {
        // Проверяем, что дочерний тег правильно ссылается на родительский
        if (childTag.parent == null || childTag.parent!.id != tag.id) {
          dev.log(
              'ОШИБКА: Дочерний тег ${childTag.id} (${childTag.name}) не ссылается на родительский ${tag.id} (${tag.name})');
        }
      }
    } else if (tag.children.isNotEmpty) {
      // У тега есть дочерние ссылки, но в иерархии объекта их нет - это нормально
      dev.log(
          'ИНФОРМАЦИЯ: У тега ${tag.id} (${tag.name}) есть ${tag.children.length} дочерних тегов, но ни один не найден в тегах объекта');
    }

    // Определяем иконку для тега
    fm.IconData getTagIcon() {
      // Специальная иконка для тренажерного зала
      if (level == 0 &&
          (tag.name.toLowerCase().contains('тренажерный зал') ||
              tag.id.toLowerCase() == 'gymid')) {
        return fm.Icons.fitness_center;
      }

      // Для родительских тегов используем стрелку вниз (как раскрывающееся меню)
      if (hasChildren) {
        return fm.Icons.label;
      }

      // Для обычных тегов используем маркер
      return fm.Icons.label;
    }

    // Определяем цвет для иконки
    fm.Color getTagIconColor() {
      // Специальный цвет для тренажерного зала
      if (level == 0 &&
          (tag.name.toLowerCase().contains('тренажерный зал') ||
              tag.id.toLowerCase() == 'gymid')) {
        return fm.Colors.indigo;
      }

      // Светло-бирюзовый для родительских тегов
      if (hasChildren) {
        return fm.Colors.teal.shade300;
      }

      // Серый для обычных тегов
      return fm.Colors.grey;
    }

    return fm.Padding(
      // Уменьшаем вертикальный отступ между тегами для большей компактности
      padding: fm.EdgeInsets.only(left: level > 0 ? 12.0 : 0, bottom: 4),
      child: fm.Row(
        crossAxisAlignment: fm.CrossAxisAlignment.start,
        children: [
          // Основное содержимое тега и его дочерних элементов
          fm.Expanded(
            child: fm.Column(
              crossAxisAlignment: fm.CrossAxisAlignment.start,
              children: [
                // Текущий тег
                fm.Row(
                  mainAxisSize: fm.MainAxisSize.min,
                  children: [
                    // Иконка, указывающая тип тега, с прозрачностью 60%
                    fm.Opacity(
                      opacity: 0.6,
                      child: fm.Icon(
                        getTagIcon(),
                        size: 16,
                        color: getTagIconColor(),
                      ),
                    ),
                    const fm.SizedBox(width: 8),
                    fm.Flexible(
                      child: fm.Text(
                        tag.name,
                        style: fm.TextStyle(
                          fontWeight: level == 0
                              ? fm.FontWeight.bold
                              : fm.FontWeight.normal,
                          color: level == 0
                              ? fm.Colors.blue.shade700
                              : fm.Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // Если есть дочерние теги, рекурсивно отображаем их со структурной линией
                if (hasChildren)
                  fm.Padding(
                    padding: const fm.EdgeInsets.only(top: 2, left: 12),
                    child: fm.Row(
                      crossAxisAlignment: fm.CrossAxisAlignment.start,
                      children: [
                        // Содержимое дочерних тегов
                        fm.Expanded(
                          child: fm.Column(
                            crossAxisAlignment: fm.CrossAxisAlignment.start,
                            children: childTags
                                .map((childTag) => _buildTagHierarchyItem(
                                    childTag, tagsByParent, level + 1))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return fm.Container(
          decoration: const fm.BoxDecoration(
            color: fm.Colors.white,
            borderRadius: fm.BorderRadius.vertical(top: fm.Radius.circular(16)),
          ),
          child: fm.Column(
            crossAxisAlignment: fm.CrossAxisAlignment.stretch,
            children: [
              // Ручка для перетаскивания
              fm.Center(
                child: fm.Container(
                  margin: const fm.EdgeInsets.only(top: 8, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: fm.BoxDecoration(
                    color: fm.Colors.grey.shade300,
                    borderRadius: fm.BorderRadius.circular(2),
                  ),
                ),
              ),

              // Фотография объекта или заглушка
              _buildPhotoGallery(),

              // Информация об объекте
              fm.Padding(
                padding: const fm.EdgeInsets.all(16),
                child: fm.Column(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    // Название объекта
                    fm.Text(
                      widget.placemark.name,
                      style: fm.Theme.of(context).textTheme.headlineMedium,
                    ),

                    // Описание объекта
                    fm.Text(
                      widget.placemark.description ?? 'Нет описания',
                      style:
                          fm.Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: fm.Colors.grey.shade600,
                              ),
                    ),
                  ],
                ),
              ),

              // Вкладки (табы)
              fm.TabBar(
                controller: _tabController,
                labelColor: fm.Colors.blue.shade900,
                unselectedLabelColor: fm.Colors.grey,
                tabs: const [
                  fm.Tab(text: 'Описание'),
                  fm.Tab(text: 'Теги'),
                ],
              ),

              // Содержимое вкладок
              fm.Expanded(
                child: fm.TabBarView(
                  controller: _tabController,
                  children: [
                    // Вкладка "Описание"
                    fm.ListView(
                      controller: scrollController,
                      padding: const fm.EdgeInsets.all(16),
                      children: [
                        // Адрес
                        fm.Row(
                          crossAxisAlignment: fm.CrossAxisAlignment.start,
                          children: [
                            const fm.Icon(fm.Icons.location_on,
                                color: fm.Colors.black),
                            const fm.SizedBox(width: 16),
                            fm.Expanded(
                              child: fm.Column(
                                crossAxisAlignment: fm.CrossAxisAlignment.start,
                                children: [
                                  fm.Text('Адрес',
                                      style: fm.Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  // Показываем адрес, если он есть, иначе заглушку
                                  fm.Text(
                                    widget.placemark.address ??
                                        'Адрес не указан',
                                    style: fm.TextStyle(
                                      color: widget.placemark.address != null
                                          ? fm.Colors.black87
                                          : fm.Colors.grey,
                                    ),
                                  ),
                                  // Если есть адрес, показываем кнопку маршрута
                                  if (widget.placemark.address != null)
                                    fm.TextButton(
                                      onPressed: () => _launchRoute(
                                          widget.placemark.location.latitude,
                                          widget.placemark.location.longitude),
                                      style: fm.TextButton.styleFrom(
                                        padding: fm.EdgeInsets.zero,
                                        alignment: fm.Alignment.centerLeft,
                                      ),
                                      child: const fm.Text('Маршрут'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        fm.Divider(color: fm.Colors.grey.shade300),

                        // Контакты
                        fm.Row(
                          crossAxisAlignment: fm.CrossAxisAlignment.start,
                          children: [
                            const fm.Icon(fm.Icons.phone,
                                color: fm.Colors.black),
                            const fm.SizedBox(width: 16),
                            fm.Expanded(
                              child: fm.Column(
                                crossAxisAlignment: fm.CrossAxisAlignment.start,
                                children: [
                                  fm.Text('Контакты',
                                      style: fm.Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  // Показываем телефон, если он есть, иначе заглушку
                                  fm.Text(
                                    widget.placemark.phone != null
                                        ? _formatPhoneNumber(
                                            widget.placemark.phone!)
                                        : 'Телефон не указан',
                                    style: fm.TextStyle(
                                      color: widget.placemark.phone != null
                                          ? fm.Colors.black87
                                          : fm.Colors.grey,
                                    ),
                                  ),
                                  // Если есть телефон, добавляем кнопку для звонка
                                  if (widget.placemark.phone != null)
                                    fm.TextButton(
                                      onPressed: () {
                                        _makePhoneCall(widget.placemark.phone!);
                                      },
                                      style: fm.TextButton.styleFrom(
                                        padding: fm.EdgeInsets.zero,
                                        alignment: fm.Alignment.centerLeft,
                                      ),
                                      child: const fm.Text('Позвонить'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        fm.Divider(color: fm.Colors.grey.shade300),

                        // Расстояние до объекта
                        fm.Row(
                          crossAxisAlignment: fm.CrossAxisAlignment.start,
                          children: [
                            const fm.Icon(fm.Icons.directions,
                                color: fm.Colors.black),
                            const fm.SizedBox(width: 16),
                            fm.Expanded(
                              child: fm.Column(
                                crossAxisAlignment: fm.CrossAxisAlignment.start,
                                children: [
                                  fm.Text('Расстояние',
                                      style: fm.Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  // Показываем расстояние, если оно рассчитано
                                  fm.Text(
                                    widget.distance != null
                                        ? _formatDistance(widget.distance!)
                                        : 'Расстояние не определено',
                                    style: fm.TextStyle(
                                      color: widget.distance != null
                                          ? fm.Colors.black87
                                          : fm.Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        fm.Divider(color: fm.Colors.grey.shade300),

                        // Разнообразие оборудования
                        fm.Row(
                          crossAxisAlignment: fm.CrossAxisAlignment.start,
                          children: [
                            const fm.Icon(fm.Icons.fitness_center,
                                color: fm.Colors.black),
                            const fm.SizedBox(width: 16),
                            fm.Expanded(
                              child: fm.Column(
                                crossAxisAlignment: fm.CrossAxisAlignment.start,
                                children: [
                                  fm.Text('Разнообразие оборудования',
                                      style: fm.Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  // Индикатор разнообразия
                                  if (widget.placemark.equipmentDiversity !=
                                      null)
                                    _buildDiversityIndicator(
                                        widget.placemark.equipmentDiversity!)
                                  else
                                    const fm.Text(
                                      'Нет данных о разнообразии оборудования',
                                      style: fm.TextStyle(
                                        color: fm.Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Вкладка "Теги"
                    fm.SingleChildScrollView(
                      controller: scrollController,
                      child: _buildTagsTab(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Возвращает виджет фотогалереи или заглушку "нет фото"
  fm.Widget _buildPhotoGallery() {
    // Если нет фотографий, показываем заглушку
    if (widget.placemark.photoUrls == null ||
        widget.placemark.photoUrls!.isEmpty) {
      return fm.Container(
        height: 200,
        color: fm.Colors.grey.shade200,
        child: _buildNoPhotoPlaceholder(),
      );
    }

    // Если есть фотографии, показываем галерею
    return fm.SizedBox(
      height: 200,
      child: fm.Stack(
        children: [
          // Слайдер с фотографиями
          fm.PageView.builder(
            controller: _photoPageController,
            itemCount: widget.placemark.photoUrls!.length,
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return fm.GestureDetector(
                onTap: () => _openFullScreenGallery(index),
                child: fm.Image.network(
                  widget.placemark.photoUrls![index],
                  fit: fm.BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _buildNoPhotoPlaceholder(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return fm.Center(
                      child: fm.CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  // Важно: устанавливаем правильный ключ на каждое изображение
                  // для предотвращения конфликтов кеширования
                  key: fm.ValueKey(
                      'gallery_image_${widget.placemark.photoUrls![index]}'),
                ),
              );
            },
          ),

          // Индикатор страниц для фотогалереи
          if (widget.placemark.photoUrls != null &&
              widget.placemark.photoUrls!.length > 1)
            fm.Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: fm.Row(
                mainAxisAlignment: fm.MainAxisAlignment.center,
                children: List.generate(
                  widget.placemark.photoUrls!.length,
                  (index) => fm.Container(
                    width: 8,
                    height: 8,
                    margin: const fm.EdgeInsets.symmetric(horizontal: 4),
                    decoration: fm.BoxDecoration(
                      shape: fm.BoxShape.circle,
                      color: _currentPhotoIndex == index
                          ? fm.Colors.white
                          : fm.Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Заглушка при отсутствии фотографий
  fm.Widget _buildNoPhotoPlaceholder() {
    return fm.Center(
      child: fm.Column(
        mainAxisAlignment: fm.MainAxisAlignment.center,
        children: [
          fm.Opacity(
            opacity: 0.3, // добавляем 30% прозрачности
            child: fm.Image.asset(
              'assets/images/no_photo.png',
              width: 64,
              height: 64,
            ),
          ),
          const fm.SizedBox(height: 8),
          fm.Text('Нет фото',
              style: fm.TextStyle(color: fm.Colors.grey.withOpacity(0.5))),
        ],
      ),
    );
  }

  /// Открывает галерею на полный экран
  void _openFullScreenGallery(int initialIndex) {
    if (widget.placemark.photoUrls == null) return;

    dev.log('Открываем полноэкранную галерею с фото #$initialIndex');
    fm.Navigator.of(context).push(
      fm.PageRouteBuilder(
        opaque: false,
        barrierColor: fm.Colors.black87,
        pageBuilder: (fm.BuildContext context, _, __) {
          return _FullScreenPhotoGallery(
            photoUrls: widget.placemark.photoUrls!,
            initialIndex: initialIndex,
          );
        },
      ),
    );
  }

  /// Добавляю новый приватный метод для запуска URL маршрута
  Future<void> _launchRoute(double latitude, double longitude) async {
    // URL для Яндекс Карт (построение маршрута от текущей позиции до указанных координат)
    final yandexMapsUrl = Uri.parse(
        'yandexmaps://maps.yandex.ru/?rtext=~$latitude,$longitude&rtt=auto');
    // URL для 2ГИС (построение маршрута)
    final dgisUrl = Uri.parse(
        'dgis://2gis.ru/routeSearch/rsType/car/to/$longitude,$latitude');
    // URL для Google Карт (веб версия для построения маршрута)
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');

    dev.log('Попытка открыть маршрут для координат: $latitude, $longitude');

    // Пытаемся открыть в Яндекс Картах
    if (await canLaunchUrl(yandexMapsUrl)) {
      dev.log('Открываем в Яндекс Картах: $yandexMapsUrl');
      await launchUrl(yandexMapsUrl);
    }
    // Если Яндекс Карты не доступны, пытаемся открыть в 2ГИС
    else if (await canLaunchUrl(dgisUrl)) {
      dev.log('Открываем в 2ГИС: $dgisUrl');
      await launchUrl(dgisUrl);
    }
    // Если ни Яндекс Карты, ни 2ГИС не доступны, пытаемся открыть в Google Картах (веб)
    else if (await canLaunchUrl(googleMapsUrl)) {
      dev.log('Открываем в Google Картах (веб): $googleMapsUrl');
      await launchUrl(googleMapsUrl);
    } else {
      // Если ни одно приложение не найдено
      dev.log('Не удалось найти ни одно приложение для построения маршрута.');
      if (mounted) {
        fm.ScaffoldMessenger.of(context).showSnackBar(
          const fm.SnackBar(
            content:
                fm.Text('Не удалось найти приложение для построения маршрута.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Открывает приложение набора номера с предустановленным номером телефона
  Future<void> _makePhoneCall(String phoneNumber) async {
    // Очищаем номер от всех символов кроме цифр
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final phoneUri = Uri.parse('tel:$cleanedNumber');

    dev.log('Попытка позвонить по номеру: $cleanedNumber через URI: $phoneUri');

    // Проверяем, можно ли запустить URL для звонка
    if (await canLaunchUrl(phoneUri)) {
      dev.log('Открываем номеронабиратель для номера: $cleanedNumber');
      await launchUrl(phoneUri);
    } else {
      dev.log('Не удалось открыть номеронабиратель для URI: $phoneUri');
      if (mounted) {
        fm.ScaffoldMessenger.of(context).showSnackBar(
          const fm.SnackBar(
            content: fm.Text('Не удалось открыть приложение для звонка'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Строит индикатор разнообразия оборудования
  fm.Widget _buildDiversityIndicator(double diversity) {
    // Процент разнообразия
    final int percentage = (diversity * 100).round();

    // Определяем цвет индикатора в зависимости от процента
    fm.Color indicatorColor;
    if (percentage > 60) {
      indicatorColor = fm.Colors.green;
    } else if (percentage >= 30) {
      indicatorColor = fm.Colors.orange;
    } else {
      indicatorColor = fm.Colors.red;
    }

    return fm.Column(
      crossAxisAlignment: fm.CrossAxisAlignment.start,
      children: [
        fm.SizedBox(height: 4),
        // Текстовое отображение процента
        fm.Text(
          '$percentage%',
          style: fm.TextStyle(
            color: indicatorColor,
            fontWeight: fm.FontWeight.bold,
            fontSize: 16,
          ),
        ),
        fm.SizedBox(height: 8),
        // Шкала процента
        fm.Container(
          width: double.infinity,
          height: 8,
          decoration: fm.BoxDecoration(
            color: fm.Colors.grey.shade200,
            borderRadius: fm.BorderRadius.circular(4),
          ),
          child: fm.FractionallySizedBox(
            alignment: fm.Alignment.centerLeft,
            widthFactor: diversity,
            child: fm.Container(
              decoration: fm.BoxDecoration(
                color: indicatorColor,
                borderRadius: fm.BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        // Пояснение
        fm.SizedBox(height: 4),
        fm.Text(
          percentage > 60
              ? 'Широкий уровень'
              : percentage >= 30
                  ? 'Средний уровень'
                  : 'Ограниченный уровень',
          style: fm.TextStyle(
            color: fm.Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Виджет для просмотра фотографий на полном экране с кнопками навигации
class _FullScreenPhotoGallery extends fm.StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullScreenPhotoGallery({
    required this.photoUrls,
    required this.initialIndex,
  });

  @override
  fm.State<_FullScreenPhotoGallery> createState() =>
      _FullScreenPhotoGalleryState();
}

class _FullScreenPhotoGalleryState extends fm.State<_FullScreenPhotoGallery> {
  late fm.PageController _pageController;
  late int _currentIndex;

  // Список обработчиков предзагрузки изображений полноэкранного режима
  final List<fm.ImageStreamListener> _fullscreenImageHandlers = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = fm.PageController(initialPage: widget.initialIndex);

    // Предзагружаем все фото для полноэкранного просмотра
    _precacheFullScreenImages();
  }

  /// Предзагрузка всех изображений для полноэкранного просмотра
  void _precacheFullScreenImages() {
    dev.log(
        'Начинаем предзагрузку ${widget.photoUrls.length} изображений для полноэкранного просмотра');

    for (final photoUrl in widget.photoUrls) {
      final imageProvider = fm.NetworkImage(photoUrl);

      // Создаем слушателя загрузки изображения
      final imageStreamListener = fm.ImageStreamListener(
        (fm.ImageInfo info, bool syncCall) {
          // Изображение загружено успешно
          if (mounted) {
            dev.log('Предзагружено полноэкранное изображение: $photoUrl');
          }
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          // Ошибка загрузки изображения
          if (mounted) {
            dev.log(
                'Ошибка предзагрузки полноэкранного изображения: $photoUrl - $exception');
          }
        },
      );

      // Начинаем загрузку изображения и добавляем слушателя
      final imageStream = imageProvider.resolve(const fm.ImageConfiguration());
      imageStream.addListener(imageStreamListener);

      // Сохраняем слушателя для последующей отмены
      _fullscreenImageHandlers.add(imageStreamListener);
    }
  }

  /// Отменяет все незавершенные предзагрузки изображений
  void _cancelImagePreloading() {
    dev.log('Отмена всех незавершенных загрузок полноэкранных изображений');

    for (int i = 0;
        i < widget.photoUrls.length && i < _fullscreenImageHandlers.length;
        i++) {
      try {
        final imageProvider = fm.NetworkImage(widget.photoUrls[i]);
        final imageStream =
            imageProvider.resolve(const fm.ImageConfiguration());
        imageStream.removeListener(_fullscreenImageHandlers[i]);
      } catch (e) {
        dev.log('Ошибка при отмене загрузки полноэкранного изображения: $e');
      }
    }

    _fullscreenImageHandlers.clear();
  }

  @override
  void dispose() {
    // Отменяем все незавершенные загрузки изображений
    _cancelImagePreloading();
    _pageController.dispose();
    super.dispose();
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
      backgroundColor: fm.Colors.transparent,
      body: fm.Stack(
        fit: fm.StackFit.expand,
        children: [
          // Фотогалерея на полный экран
          fm.GestureDetector(
            onTap: () => fm.Navigator.of(context).pop(),
            child: fm.PageView.builder(
              controller: _pageController,
              itemCount: widget.photoUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return fm.InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: fm.Center(
                    child: fm.Image.network(
                      widget.photoUrls[index],
                      fit: fm.BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return fm.Center(
                          child: fm.CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: fm.Colors.white70,
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, stack) => const fm.Center(
                        child: fm.Text(
                          'Ошибка загрузки изображения',
                          style: fm.TextStyle(color: fm.Colors.white),
                        ),
                      ),
                      // Важно: устанавливаем правильный ключ на каждое изображение
                      key: fm.ValueKey(
                          'fullscreen_image_${widget.photoUrls[index]}'),
                    ),
                  ),
                );
              },
            ),
          ),

          // Кнопка "Назад" (стрелка влево)
          if (_currentIndex > 0)
            fm.Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: fm.Center(
                child: fm.IconButton(
                  icon: fm.Icon(fm.Icons.arrow_back_ios,
                      color: fm.Colors.white.withOpacity(0.7), size: 32),
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: fm.Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),

          // Кнопка "Вперед" (стрелка вправо)
          if (_currentIndex < widget.photoUrls.length - 1)
            fm.Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: fm.Center(
                child: fm.IconButton(
                  icon: fm.Icon(fm.Icons.arrow_forward_ios,
                      color: fm.Colors.white
                          .withOpacity(0.7), // добавлена прозрачность
                      size: 32),
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: fm.Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),

          // Кнопка "Закрыть" (сверху справа)
          fm.Positioned(
            top: fm.MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: fm.CircleAvatar(
              backgroundColor: fm.Colors.black45,
              child: fm.IconButton(
                icon: const fm.Icon(fm.Icons.close, color: fm.Colors.white),
                onPressed: () => fm.Navigator.of(context).pop(),
              ),
            ),
          ),

          // Счетчик фотографий (сверху слева)
          fm.Positioned(
            top: fm.MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: fm.Container(
              padding:
                  const fm.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: fm.BoxDecoration(
                color: fm.Colors.black45,
                borderRadius: fm.BorderRadius.circular(16),
              ),
              child: fm.Text(
                '${_currentIndex + 1}/${widget.photoUrls.length}',
                style: const fm.TextStyle(color: fm.Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
