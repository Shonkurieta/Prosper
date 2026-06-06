import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class BookmarkService {
  String get baseUrl => ApiConstants.baseUrl;

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
  Future<void> addBookmark(String token, int bookId, {String? status}) async {
    String url = '$baseUrl/bookmarks/$bookId';
    if (status != null) {
      url += '?status=$status';
    }
    
    final response = await http.post(
      Uri.parse(url),
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

  /// Переводит книгу в статус «Прочитано» если она в закладках.
  /// Вызывается Flutter-стороной при открытии последней главы.
  /// Ошибки обрабатываются вызывающей стороной (обычно — тихо).
  Future<void> markAsCompleted(String token, int bookId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bookmarks/$bookId/complete'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Ошибка обновления статуса: ${response.statusCode}');
    }
  }

  // Подписаться на обновления новеллы
  Future<void> subscribe(String token, int bookId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookmarks/$bookId/subscribe'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка подписки: ${response.statusCode}');
    }
  }

  // Отписаться от обновлений новеллы
  Future<void> unsubscribe(String token, int bookId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bookmarks/$bookId/subscribe'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Ошибка отписки: ${response.statusCode}');
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
        return 'Читаю';
      case COMPLETED:
        return 'Прочитанное';
      case FAVORITE:
        return 'Любимое';
      case DROPPED:
        return 'Брошенное';
      case PLANNED:
        return 'В планах';
      default:
        return 'Читаю';
    }
  }

  // Получить иконку для статуса
  static String getStatusIcon(String status) {
    switch (status) {
      case READING:
        return '';
      case COMPLETED:
        return '';
      case FAVORITE:
        return '';
      case DROPPED:
        return '';
      case PLANNED:
        return '';
      default:
        return '';
    }
  }
}