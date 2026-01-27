import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  final String baseUrl = 'http://10.22.142.182:8080/api';

  // ========================================
  // ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ
  // ========================================

  /// Получить профиль текущего пользователя
  Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      print('=== GET PROFILE REQUEST ===');
      print('URL: $baseUrl/user/profile');
      
      // Очистка токена от возможного дубля Bearer
      token = token.replaceFirst('Bearer ', '').trim();
      print('Token (first 30 chars): ${token.substring(0, token.length > 30 ? 30 : token.length)}...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Сервер вернул пустой ответ');
        }
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Сессия истекла. Войдите заново');
      } else if (response.statusCode == 403) {
        throw Exception('Доступ запрещен');
      } else {
        throw Exception('Ошибка загрузки профиля: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getProfile: $e');
      rethrow;
    }
  }

  /// Обновить никнейм
  Future<Map<String, dynamic>> updateNickname(String token, String nickname) async {
    try {
      print('=== UPDATE NICKNAME REQUEST ===');
      print('URL: $baseUrl/user/nickname');
      
      token = token.replaceFirst('Bearer ', '').trim();
      
      final response = await http.put(
        Uri.parse('$baseUrl/user/nickname'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'nickname': nickname}),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Ошибка обновления никнейма');
      } else if (response.statusCode == 401) {
        throw Exception('Сессия истекла');
      } else {
        throw Exception('Ошибка обновления никнейма: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updateNickname: $e');
      rethrow;
    }
  }

  /// Alias для совместимости
  Future<Map<String, dynamic>> updateProfile(String token, String newNickname) async {
    return updateNickname(token, newNickname);
  }

  /// Изменить пароль
  Future<void> changePassword(String token, String oldPassword, String newPassword) async {
    try {
      print('=== CHANGE PASSWORD REQUEST ===');
      print('URL: $baseUrl/user/password');
      
      token = token.replaceFirst('Bearer ', '').trim();

      final response = await http.put(
        Uri.parse('$baseUrl/user/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Неверный старый пароль');
      } else if (response.statusCode == 401) {
        throw Exception('Сессия истекла');
      } else {
        throw Exception('Ошибка изменения пароля: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in changePassword: $e');
      rethrow;
    }
  }

  // ========================================
  // ADMIN ФУНКЦИИ
  // ========================================

  /// Получить всех пользователей (для админа)
  Future<List<dynamic>> getAllUsers(String token) async {
    try {
      print('=== GET ALL USERS REQUEST ===');
      print('URL: $baseUrl/admin/users');
      
      token = token.replaceFirst('Bearer ', '').trim();

      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == '[]') {
          return [];
        }
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        } else if (data is Map && data.containsKey('users')) {
          return data['users'];
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Сессия истекла');
      } else if (response.statusCode == 403) {
        throw Exception('Требуются права администратора');
      } else {
        throw Exception('Ошибка загрузки пользователей: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getAllUsers: $e');
      rethrow;
    }
  }

  /// Alias для совместимости
  Future<List<dynamic>> fetchUsers(String token) async {
    return getAllUsers(token);
  }

  /// Удалить пользователя (для админа)
  Future<void> deleteUser(String token, int userId) async {
    try {
      print('=== DELETE USER REQUEST ===');
      print('URL: $baseUrl/admin/users/$userId');
      
      token = token.replaceFirst('Bearer ', '').trim();

      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Пользователь не найден');
      } else if (response.statusCode == 401) {
        throw Exception('Сессия истекла');
      } else if (response.statusCode == 403) {
        throw Exception('Доступ запрещен');
      } else {
        throw Exception('Ошибка удаления: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in deleteUser: $e');
      rethrow;
    }
  }
}