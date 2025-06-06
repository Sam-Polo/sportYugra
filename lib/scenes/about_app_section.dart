import 'package:flutter/material.dart' as fm;

/// Виджет для отображения раздела "О приложении"
class AboutAppSection extends fm.StatelessWidget {
  const AboutAppSection({super.key});

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.SafeArea(
      child: fm.Container(
        decoration: const fm.BoxDecoration(
          color: fm.Color(0xFF0A1A2F), // темно-синий фон
          borderRadius: fm.BorderRadius.vertical(top: fm.Radius.circular(16)),
        ),
        child: fm.SingleChildScrollView(
          child: fm.Padding(
            padding: const fm.EdgeInsets.all(24),
            child: fm.Column(
              mainAxisSize: fm.MainAxisSize.min,
              crossAxisAlignment: fm.CrossAxisAlignment.start,
              children: [
                // заголовок с кнопкой назад
                fm.Row(
                  children: [
                    fm.IconButton(
                      icon: const fm.Icon(fm.Icons.arrow_back,
                          color: fm.Colors.white),
                      onPressed: () => fm.Navigator.of(context).pop(),
                      tooltip: 'Назад',
                    ),
                    const fm.Text(
                      'О приложении',
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 20,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const fm.SizedBox(height: 24),

                // логотип и название приложения
                fm.Center(
                  child: fm.Column(
                    children: [
                      fm.Container(
                        width: 80,
                        height: 80,
                        decoration: fm.BoxDecoration(
                          color: const fm.Color.fromARGB(255, 47, 62,
                              78), // темно-серый синий цвет для фона иконки
                          borderRadius: fm.BorderRadius.circular(16),
                        ),
                        padding: const fm.EdgeInsets.all(
                            16), // добавляем внутренние отступы
                        child: fm.Image.asset(
                          'assets/images/start_icon_dumbbell_native.png', // иконка гантели из ассетов
                          scale: 2.0, // подбираем масштаб, если нужно
                        ),
                      ),
                      const fm.SizedBox(height: 16),
                      const fm.Text(
                        'SportYugra',
                        style: fm.TextStyle(
                          color: fm.Colors.white,
                          fontSize: 24,
                          fontWeight: fm.FontWeight.bold,
                        ),
                      ),
                      const fm.Text(
                        'Версия 1.1.0',
                        style: fm.TextStyle(
                          color: fm.Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const fm.SizedBox(height: 32),

                // описание приложения
                fm.Row(
                  children: [
                    const fm.Icon(fm.Icons.info_outline,
                        color: fm.Colors.white,
                        size: 20), // иконка для описания
                    const fm.SizedBox(width: 8),
                    const fm.Text(
                      'О приложении',
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 18,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const fm.SizedBox(height: 8),
                const fm.Text(
                  'SportYugra — мобильное приложение для поиска, фильтрации и просмотра спортивных объектов в Ханты-Мансийске. Приложение использует интерактивную карту Яндекс.Карт для удобной навигации.',
                  style: fm.TextStyle(
                    color: fm.Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const fm.SizedBox(height: 24),

                // разделитель
                fm.Divider(color: fm.Colors.white.withOpacity(0.2)),
                const fm.SizedBox(height: 24),

                // функциональность
                fm.Row(
                  children: [
                    const fm.Text(
                      'Основные функции',
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 18,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const fm.SizedBox(height: 16),
                _buildFeatureItem(fm.Icons.map,
                    'Интерактивная карта с метками спортивных объектов'),
                _buildFeatureItem(fm.Icons.search, 'Поиск объектов и тегов'),
                _buildFeatureItem(
                    fm.Icons.filter_list, 'Фильтрация по типам оборудования'),
                _buildFeatureItem(
                    fm.Icons.photo_library, 'Фотогалерея объектов'),
                _buildFeatureItem(
                    fm.Icons.place, 'Расчет расстояния до объектов'),
                _buildFeatureItem(
                    fm.Icons.info_outline, 'Информация об объектах'),
                _buildFeatureItem(
                    fm.Icons.analytics, 'Разнообразие оборудования'),
                _buildFeatureItem(
                    fm.Icons.update, 'История изменений тегов объектов'),
                _buildFeatureItem(
                    fm.Icons.support_agent, 'Поддержка и обратная связь'),
                const fm.SizedBox(height: 24),

                // разделитель
                fm.Divider(color: fm.Colors.white.withOpacity(0.2)),
                const fm.SizedBox(height: 24),

                // описание функций
                fm.Row(
                  children: [
                    const fm.Text(
                      'Описание функций',
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 18,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const fm.SizedBox(height: 16),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.map,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Интерактивная карта',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Интегрированная карта местности при помощи YandexMapKit, отражающая детально все объекты на карте, включая здания, дороги, магазины, и прочие ориентиры. На карту добавлены отдельно метки спортивных объектов. Также карта отражает текущее положение пользователя и включает в себя возможность вернуть положение камеры к местоположению пользователя',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.search,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Поиск объектов и тегов',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Поиск включает в себя название объектов и поиск всех тегов, которые есть в системе, чтобы быстро найти и выбрать их для фильтрации.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.filter_list,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Фильтрация по типам оборудования',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Возможность фильтрации объектов по типам имеющегося оборудования, что позволяет быстро найти подходящий спортивный объект.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.photo_library,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Фотогалерея объектов',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Фотографии спортивных объектов, позволяющие оценить их внешний вид и оснащение перед посещением.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.place,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Расчет расстояния до объектов',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Расчет реального расстояния от пользователя до объекта с использованием формулы гаверсинусов, учитывающей кривизну Земли.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.info_outline,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Информация об объектах',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Подробная информация включает описание, адрес, расстояние, контакты (телефон) и разнообразие оборудования. Отдельный раздел для просмотра всех имеющихся тегов у объекта в виде иерархии.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.analytics,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Разнообразие оборудования',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Расчет процента имеющихся тегов у объекта среди всех возможных тегов в системе. Это позволяет быстро оценить наполненность тренажерного зала и разнообразие доступного оборудования.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.update,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'История изменений',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Возможность просмотра истории изменений тегов спортивных объектов. Отображает кто, когда и какие изменения внес, включая добавленные и удаленные теги каждого объекта.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                fm.Row(
                  crossAxisAlignment: fm.CrossAxisAlignment.start,
                  children: [
                    const fm.Icon(fm.Icons.support_agent,
                        color: fm.Colors.white70, size: 18),
                    const fm.SizedBox(width: 8),
                    fm.Expanded(
                      child: fm.Column(
                        crossAxisAlignment: fm.CrossAxisAlignment.start,
                        children: [
                          const fm.Text(
                            'Поддержка',
                            style: fm.TextStyle(
                              color: fm.Colors.white,
                              fontSize: 16,
                              fontWeight: fm.FontWeight.bold,
                            ),
                          ),
                          const fm.Padding(
                            padding: fm.EdgeInsets.only(bottom: 12),
                            child: fm.Text(
                              'Функция обратной связи с разработчиками через Email или Telegram для решения проблем, вопросов или предложений по улучшению приложения.',
                              style: fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const fm.SizedBox(height: 24),

                // разделитель
                fm.Divider(color: fm.Colors.white.withOpacity(0.2)),
                const fm.SizedBox(height: 24),

                // разработчики
                fm.Row(
                  children: [
                    const fm.Icon(fm.Icons.code,
                        color: fm.Colors.white,
                        size: 20), // иконка для разработчиков
                    const fm.SizedBox(width: 8),
                    const fm.Text(
                      'Разработчики',
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 18,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const fm.SizedBox(height: 16),
                const fm.Text(
                  'Приложение разработано в рамках дипломного проекта.',
                  style: fm.TextStyle(
                    color: fm.Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const fm.SizedBox(height: 8),
                const fm.Text(
                  '© 2025 SportYugra',
                  style: fm.TextStyle(
                    color: fm.Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const fm.SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // вспомогательный метод для создания элементов функциональности
  fm.Widget _buildFeatureItem(fm.IconData icon, String text) {
    return fm.Padding(
      padding: const fm.EdgeInsets.only(bottom: 12),
      child: fm.Row(
        crossAxisAlignment: fm.CrossAxisAlignment.start,
        children: [
          fm.Icon(
            icon,
            color: const fm.Color(0xFFFC4C4C),
            size: 20,
          ),
          const fm.SizedBox(width: 12),
          fm.Expanded(
            child: fm.Text(
              text,
              style: const fm.TextStyle(
                color: fm.Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
