import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReadingProgressService {
  static const String _progressKey = 'reading_progress';

  // Сохранить прогресс чтения
  Future<void> saveProgress({
    required int bookId,
    required int chapterOrder,
    required String bookTitle,
    required String? coverUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final progressMap = await getProgressMap();
    
    progressMap[bookId.toString()] = {
      'bookId': bookId,
      'chapterOrder': chapterOrder,
      'bookTitle': bookTitle,
      'coverUrl': coverUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    await prefs.setString(_progressKey, json.encode(progressMap));
  }

  // Получить прогресс для конкретной книги
  Future<Map<String, dynamic>?> getProgress(int bookId) async {
    final progressMap = await getProgressMap();
    return progressMap[bookId.toString()];
  }

  // Получить всю карту прогресса
  Future<Map<String, dynamic>> getProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString(_progressKey);
    
    if (progressJson == null || progressJson.isEmpty) {
      return {};
    }
    
    try {
      return Map<String, dynamic>.from(json.decode(progressJson));
    } catch (e) {
      return {};
    }
  }

  // Получить список книг для "Продолжить чтение" (отсортировано по времени)
  Future<List<Map<String, dynamic>>> getRecentProgress({int limit = 10}) async {
    final progressMap = await getProgressMap();
    final progressList = progressMap.values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    
    // Сортировка по timestamp (последние первые)
    progressList.sort((a, b) {
      final timeA = a['timestamp'] as int? ?? 0;
      final timeB = b['timestamp'] as int? ?? 0;
      return timeB.compareTo(timeA);
    });
    
    return progressList.take(limit).toList();
  }

  // Очистить весь прогресс
  Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  // Удалить прогресс конкретной книги
  Future<void> removeProgress(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final progressMap = await getProgressMap();
    progressMap.remove(bookId.toString());
    await prefs.setString(_progressKey, json.encode(progressMap));
  }
}