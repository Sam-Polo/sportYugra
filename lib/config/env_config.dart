import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Класс для работы с переменными окружения
class EnvConfig {
  /// Загружает переменные окружения из файла .env
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  /// Возвращает значение переменной окружения по ключу
  static String get(String key) {
    return dotenv.env[key] ?? '';
  }

  /// Email разработчика
  static String get developerEmail => get('DEVELOPER_EMAIL');

  /// Telegram разработчика
  static String get developerTelegram => get('DEVELOPER_TELEGRAM');
}
