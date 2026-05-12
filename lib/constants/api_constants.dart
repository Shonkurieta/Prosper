import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl => '${dotenv.env['API_BASE_URL']}/api';
  static String get authUrl => '$baseUrl/auth';
  static String get adminUrl => '$baseUrl/admin';
  static String get booksUrl => '$baseUrl/books';
  
  static String getCoverUrl(String coverPath) {
    final apiBase = dotenv.env['API_BASE_URL'] ?? 'http://10.177.112.182:8080';
    
    if (coverPath.startsWith('/')) {
      return '$apiBase$coverPath';
    }
    return '$apiBase/$coverPath';
  }
}