import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:prosper/constants/api_constants.dart';

class CommentNotificationService {
  Future<List<dynamic>> getNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/comment-notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Не авторизован');
      } else {
        throw Exception('Ошибка загрузки уведомлений');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<List<dynamic>> getUnreadNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/comment-notifications/unread'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Не авторизован');
      } else {
        throw Exception('Ошибка загрузки уведомлений');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<int> getUnreadCount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/comment-notifications/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final count = jsonDecode(response.body);
        return count as int;
      } else if (response.statusCode == 401) {
        throw Exception('Не авторизован');
      } else {
        throw Exception('Ошибка получения количества уведомлений');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<void> markAsRead(String token, int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/comment-notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка отметки уведомления как прочитанного');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<void> deleteNotification(String token, int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/comment-notifications/$notificationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка удаления уведомления');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }
}
