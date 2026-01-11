import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class BookmarkService {
  final String baseUrl = ApiConstants.baseUrl;

  // Enum для статусов (синхронизирован с backend)
  static const String READING = 'READING';
  static const String COMPLETED = 'COMPLETED';
  static const String FAVORITE = 'FAVORITE';
  static const String DROPPED = 'DROPPED';
  static const String PLANNED = 'PLANNED';

  // Получить все закладки или с фильтром по статусу
  Future<List<dynamic>> getBookmarks(String token, {String? status}) async {
    String url = '$baseUrl/bookmarks';
    if (status != null) {
      url += '?status=$status';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Ошибка загрузки закладок: ${response.statusCode}');
    }
  }

  // Получить прогресс для конкретной новеллы
  Future<Map<String, dynamic>> getProgress(String token, int bookId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bookmarks/progress/$bookId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Ошибка загрузки прогресса');
    }
  }

  // Добавить закладку
  Future<void> addBookmark(String token, int bookId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookmarks/$bookId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка добавления закладки');
    }
  }

  // Обновить статус закладки
  Future<void> updateBookmarkStatus(String token, int bookmarkId, String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bookmarks/$bookmarkId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка обновления статуса');
    }
  }

  // Обновить прогресс чтения
  Future<void> updateProgress(String token, int bookId, int currentChapter) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bookmarks/$bookId/progress'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'currentChapter': currentChapter}),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка обновления прогресса');
    }
  }

  // Удалить закладку
  Future<void> removeBookmark(String token, int bookId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bookmarks/$bookId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления закладки');
    }
  }

  // Получить отображаемое имя статуса
  static String getStatusDisplayName(String status) {
    switch (status) {
      case READING:
        return 'В процессе';
      case COMPLETED:
        return 'Прочитанное';
      case FAVORITE:
        return 'Любимое';
      case DROPPED:
        return 'Брошенное';
      case PLANNED:
        return 'В планах';
      default:
        return 'В процессе';
    }
  }

  // Получить иконку для статуса
  static String getStatusIcon(String status) {
    switch (status) {
      case READING:
        return '📖';
      case COMPLETED:
        return '✅';
      case FAVORITE:
        return '❤️';
      case DROPPED:
        return '🚫';
      case PLANNED:
        return '📅';
      default:
        return '📖';
    }
  }
}