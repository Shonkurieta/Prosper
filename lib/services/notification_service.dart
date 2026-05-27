import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class NotificationService {
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> getNotifications() async {
    final response = await http.get(
      Uri.parse(ApiConstants.notificationsUrl),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  static Future<int> getUnreadCount() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.notificationsUrl}/unread-count'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      return 0;
    }
  }

  static Future<void> markAsRead(int id) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.notificationsUrl}/$id/read'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  static Future<void> markAllAsRead() async {
    final response = await http.put(
      Uri.parse('${ApiConstants.notificationsUrl}/read-all'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
  }

  static Future<void> deleteNotification(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.notificationsUrl}/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete notification');
    }
  }

  static Future<void> deleteAllNotifications() async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.notificationsUrl}/all'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete all notifications');
    }
  }
}
