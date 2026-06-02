import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReadingProgressService {
  // Key is user-specific to prevent one user seeing another user's progress
  static Future<String> _getKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('id');
    return userId != null ? 'reading_progress_$userId' : 'reading_progress_guest';
  }

  Future<void> saveProgress({
    required int bookId,
    required int chapterOrder,
    required String bookTitle,
    required String? coverUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    final progressMap = await getProgressMap();

    progressMap[bookId.toString()] = {
      'bookId': bookId,
      'chapterOrder': chapterOrder,
      'bookTitle': bookTitle,
      'coverUrl': coverUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await prefs.setString(key, json.encode(progressMap));
  }

  Future<Map<String, dynamic>?> getProgress(int bookId) async {
    final progressMap = await getProgressMap();
    return progressMap[bookId.toString()];
  }

  Future<Map<String, dynamic>> getProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    final progressJson = prefs.getString(key);

    if (progressJson == null || progressJson.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(json.decode(progressJson));
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getRecentProgress({int limit = 10}) async {
    final progressMap = await getProgressMap();
    final progressList = progressMap.values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();

    progressList.sort((a, b) {
      final timeA = a['timestamp'] as int? ?? 0;
      final timeB = b['timestamp'] as int? ?? 0;
      return timeB.compareTo(timeA);
    });

    return progressList.take(limit).toList();
  }

  Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    await prefs.remove(key);
  }

  Future<void> removeProgress(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    final progressMap = await getProgressMap();
    progressMap.remove(bookId.toString());
    await prefs.setString(key, json.encode(progressMap));
  }
}