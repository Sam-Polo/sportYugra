import 'package:flutter/material.dart' as fm;
import 'dart:developer' as dev;
import '../data/placemarks/placemark_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Виджет для отображения детальной страницы объекта с фотогалереей
class ObjectDetailsSheet extends fm.StatefulWidget {
  final PlacemarkData placemark;

  const ObjectDetailsSheet({super.key, required this.placemark});

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

  @override
  void initState() {
    super.initState();
    _tabController = fm.TabController(length: 2, vsync: this);

    // Предзагружаем все фото объекта при открытии страницы
    _precacheAllImages();
  }

  /// Предзагрузка всех изображений для галереи
  void _precacheAllImages() {
    if (widget.placemark.photoUrls.isEmpty) return;

    dev.log(
        'Начинаем предзагрузку ${widget.placemark.photoUrls.length} изображений');

    for (final photoUrl in widget.placemark.photoUrls) {
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

    for (int i = 0;
        i < widget.placemark.photoUrls.length &&
            i < _imagePrecacheHandlers.length;
        i++) {
      try {
        final imageProvider = fm.NetworkImage(widget.placemark.photoUrls[i]);
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
        formattedNumber = '7' + formattedNumber.substring(1);
      }
    }

    // Если номер неправильной длины, возвращаем без форматирования
    if (formattedNumber.length != 11) {
      return phone; // Возвращаем оригинал, если не стандартный формат
    }

    // Форматируем как +7 (XXX) XXX-XX-XX
    return '+${formattedNumber.substring(0, 1)} (${formattedNumber.substring(1, 4)}) ${formattedNumber.substring(4, 7)}-${formattedNumber.substring(7, 9)}-${formattedNumber.substring(9)}';
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
                      widget.placemark.description,
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
                      ],
                    ),

                    // Вкладка "Теги"
                    fm.ListView(
                      controller: scrollController,
                      padding: const fm.EdgeInsets.all(16),
                      children: [
                        fm.Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.placemark.tags.isEmpty
                              ? [
                                  const fm.Chip(
                                      label: fm.Text('Теги не указаны'))
                                ]
                              : widget.placemark.tags
                                  .map((tag) => fm.Chip(label: fm.Text(tag)))
                                  .toList(),
                        ),
                      ],
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
    if (widget.placemark.photoUrls.isEmpty) {
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
            itemCount: widget.placemark.photoUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return fm.GestureDetector(
                onTap: () => _openFullScreenGallery(index),
                child: fm.Image.network(
                  widget.placemark.photoUrls[index],
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
                      'gallery_image_${widget.placemark.photoUrls[index]}'),
                ),
              );
            },
          ),

          // Индикатор страниц для фотогалереи
          if (widget.placemark.photoUrls.length > 1)
            fm.Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: fm.Row(
                mainAxisAlignment: fm.MainAxisAlignment.center,
                children: List.generate(
                  widget.placemark.photoUrls.length,
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
    dev.log('Открываем полноэкранную галерею с фото #$initialIndex');
    fm.Navigator.of(context).push(
      fm.PageRouteBuilder(
        opaque: false,
        barrierColor: fm.Colors.black87,
        pageBuilder: (fm.BuildContext context, _, __) {
          return _FullScreenPhotoGallery(
            photoUrls: widget.placemark.photoUrls,
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
        'yandexmaps://maps.yandex.ru/?rtext=~${latitude},${longitude}&rtt=auto');
    // URL для 2ГИС (построение маршрута)
    final dgisUrl = Uri.parse(
        'dgis://2gis.ru/routeSearch/rsType/car/to/${longitude},${latitude}');
    // URL для Google Карт (веб версия для построения маршрута)
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${latitude},${longitude}&travelmode=driving');

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
