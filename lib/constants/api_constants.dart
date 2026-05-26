import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get _apiBaseUrl => dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? 'http://10.174.94.182:8080') : 'http://10.174.94.182:8080';

  static String get baseUrl => '$_apiBaseUrl/api';
  static String get authUrl => '$baseUrl/auth';
  static String get adminUrl => '$baseUrl/admin';
  static String get booksUrl => '$baseUrl/books';
  static String get notificationsUrl => '$baseUrl/notifications';
  
  static String getCoverUrl(String coverPath) {
    final apiBase = _apiBaseUrl;
    
    if (coverPath.startsWith('/')) {
      return '$apiBase$coverPath';
    }
    return '$apiBase/$coverPath';
  }
}