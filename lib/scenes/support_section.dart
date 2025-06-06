import 'package:flutter/material.dart' as fm;
import 'package:url_launcher/url_launcher.dart';
import '../config/env_config.dart';

/// Виджет для отображения раздела "Поддержка"
class SupportSection extends fm.StatelessWidget {
  const SupportSection({super.key});

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
                      'Поддержка',
                      style: fm.TextStyle(
                        color: fm.Colors.white,
                        fontSize: 20,
                        fontWeight: fm.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const fm.SizedBox(height: 36),

                // Иконка поддержки
                fm.Center(
                  child: fm.Container(
                    width: 100,
                    height: 100,
                    decoration: fm.BoxDecoration(
                      color: const fm.Color.fromARGB(255, 47, 62, 78),
                      borderRadius: fm.BorderRadius.circular(50),
                    ),
                    child: const fm.Icon(
                      fm.Icons.support_agent,
                      color: fm.Colors.white,
                      size: 60,
                    ),
                  ),
                ),
                const fm.SizedBox(height: 24),

                // Заголовок поддержки
                const fm.Center(
                  child: fm.Text(
                    'Как мы можем помочь?',
                    style: fm.TextStyle(
                      color: fm.Colors.white,
                      fontSize: 22,
                      fontWeight: fm.FontWeight.bold,
                    ),
                  ),
                ),
                const fm.SizedBox(height: 12),

                // Подзаголовок
                const fm.Center(
                  child: fm.Text(
                    'Выберите способ связи с разработчиком:',
                    style: fm.TextStyle(
                      color: fm.Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: fm.TextAlign.center,
                  ),
                ),
                const fm.SizedBox(height: 36),

                // Кнопка для связи по email
                _buildContactButton(
                  icon: fm.Icons.email,
                  title: 'Написать на Email',
                  subtitle: 'Отправить сообщение разработчику',
                  onTap: _launchEmail,
                ),

                const fm.SizedBox(height: 16),

                // Кнопка для связи через Telegram
                _buildContactButton(
                  icon: fm.Icons.send,
                  title: 'Telegram',
                  subtitle: 'Быстрый способ связи для вопросов и предложений',
                  onTap: _launchTelegram,
                ),

                const fm.SizedBox(height: 36),

                // Блок для владельцев объектов
                fm.Container(
                  padding: const fm.EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                  decoration: fm.BoxDecoration(
                    color: fm.Colors.white.withOpacity(0.05),
                    borderRadius: fm.BorderRadius.circular(12),
                    border: fm.Border.all(
                      color: fm.Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: fm.Row(
                    children: [
                      fm.Icon(
                        fm.Icons.business,
                        color: fm.Colors.white70,
                        size: 32,
                      ),
                      const fm.SizedBox(width: 16),
                      fm.Expanded(
                        child: fm.Column(
                          crossAxisAlignment: fm.CrossAxisAlignment.start,
                          children: [
                            fm.Text(
                              'Для владельцев объектов',
                              style: const fm.TextStyle(
                                color: fm.Colors.white,
                                fontSize: 16,
                                fontWeight: fm.FontWeight.bold,
                              ),
                            ),
                            const fm.SizedBox(height: 4),
                            fm.Text(
                              'Вашего объекта нет на карте или Вы являетесь владельцем существующего? Свяжитесь с нами, и мы предоставим вам доступ к управлению информацией.',
                              style: const fm.TextStyle(
                                color: fm.Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const fm.SizedBox(height: 36),

                // Информация о способе связи
                const fm.Center(
                  child: fm.Text(
                    'Мы постараемся ответить в течение 24 часов',
                    style: fm.TextStyle(
                      color: fm.Colors.white54,
                      fontSize: 14,
                      fontStyle: fm.FontStyle.italic,
                    ),
                    textAlign: fm.TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Метод для создания кнопки контакта
  fm.Widget _buildContactButton({
    required fm.IconData icon,
    required String title,
    required String subtitle,
    required fm.VoidCallback onTap,
  }) {
    return fm.InkWell(
      onTap: onTap,
      borderRadius: fm.BorderRadius.circular(12),
      child: fm.Container(
        padding: const fm.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: fm.BoxDecoration(
          color: fm.Colors.white.withOpacity(0.1),
          borderRadius: fm.BorderRadius.circular(12),
        ),
        child: fm.Row(
          children: [
            fm.Container(
              width: 48,
              height: 48,
              decoration: fm.BoxDecoration(
                color: const fm.Color(0xFFFC4C4C),
                borderRadius: fm.BorderRadius.circular(24),
              ),
              child: fm.Icon(
                icon,
                color: fm.Colors.white,
                size: 24,
              ),
            ),
            const fm.SizedBox(width: 16),
            fm.Expanded(
              child: fm.Column(
                crossAxisAlignment: fm.CrossAxisAlignment.start,
                children: [
                  fm.Text(
                    title,
                    style: const fm.TextStyle(
                      color: fm.Colors.white,
                      fontSize: 18,
                      fontWeight: fm.FontWeight.bold,
                    ),
                  ),
                  fm.Text(
                    subtitle,
                    style: const fm.TextStyle(
                      color: fm.Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const fm.Icon(
              fm.Icons.arrow_forward_ios,
              color: fm.Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Метод для запуска почтового клиента
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: EnvConfig.developerEmail,
      queryParameters: {
        'subject': 'Поддержка приложения SportYugra',
        'body': 'Здравствуйте,\n\n',
      },
    );

    _launchUrl(emailUri);
  }

  // Метод для запуска Telegram
  Future<void> _launchTelegram() async {
    final telegramUsername = EnvConfig.developerTelegram.replaceAll('@', '');
    final Uri telegramUri = Uri.parse('https://t.me/$telegramUsername');

    _launchUrl(telegramUri);
  }

  // Общий метод для запуска URL
  Future<void> _launchUrl(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Не удалось открыть $uri';
      }
    } catch (e) {
      // Обработка ошибки при невозможности открыть URL
      // В реальном приложении здесь можно показать диалог с ошибкой
      print('Ошибка при открытии URL: $e');
    }
  }
}
