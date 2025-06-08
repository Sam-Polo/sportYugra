import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Класс для работы с переменными окружения
class EnvConfig {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get(String key) {
    return dotenv.env[key] ?? '';
  }

  /// Email
  static String get developerEmail => get('DEVELOPER_EMAIL');

  /// Telegram
  static String get developerTelegram => get('DEVELOPER_TELEGRAM');
}
