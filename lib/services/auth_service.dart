import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/api_constants.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
      '339366407339-h0sebq3pfi5n82olfq6g37b6m8vlppbm.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  // ВАЖНО: Убедитесь, что здесь только /api без дублирования
  String get baseUrl => ApiConstants.baseUrl;

  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    try {
      print('=== REGISTRATION REQUEST ===');
      print('URL: $baseUrl/auth/register');
      print('Username: $username');
      print('Email: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Ошибка регистрации');
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in register: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('=== LOGIN REQUEST ===');
      print('URL: $baseUrl/auth/login');
      print('Username/Email: $username');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Login successful!');
        print('Token received: ${data['token']?.substring(0, 20)}...');
        print('Role: ${data['role']}');
        return data;
      } else if (response.statusCode == 401) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Неверное имя пользователя или пароль');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Неверный запрос');
      } else if (response.statusCode == 403) {
        throw Exception('Доступ запрещен. Проверьте настройки безопасности');
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in login: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Вход через Google отменен');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print("ACCESS TOKEN: ${googleAuth.accessToken}");
      print("ID TOKEN: ${googleAuth.idToken}");
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Не удалось получить ID Token от Google');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'idToken': idToken,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Ошибка входа через Google');
      }
    } catch (e) {
      print('Error in googleLogin: $e');
      rethrow;
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data['message'];
      } else {
        throw Exception(data['message'] ?? 'Ошибка запроса сброса пароля');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> resetPassword(String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data['message'];
      } else {
        throw Exception(data['message'] ?? 'Ошибка сброса пароля');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Тестовый метод для проверки доступности сервера
  Future<bool> testConnection() async {
    try {
      print('Testing connection to: $baseUrl/auth/test');
      final response = await http.get(
        Uri.parse('$baseUrl/auth/test'),
      ).timeout(const Duration(seconds: 5));
      
      print('Test connection status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}