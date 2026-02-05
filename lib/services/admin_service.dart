import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import '../constants/api_constants.dart';

class AdminService {
  static final String baseUrl = ApiConstants.adminUrl;

  final String token;

  AdminService(this.token);

  Map<String, String> get headers => {
        'Authorization': 'Bearer $token',
      };

  Future<List<dynamic>> getBooks() async {
    final url = Uri.parse('$baseUrl/books');
    print('📡 [getBooks] GET $url');
    final res = await http.get(url, headers: headers);

    print('📡 [getBooks] STATUS: ${res.statusCode}');
    print('📦 [getBooks] BODY: ${res.body}');

    if (res.statusCode == 200) {
      if (res.body.isEmpty) return [];
      return jsonDecode(res.body);
    } else if (res.statusCode == 403) {
      throw Exception('Нет прав доступа (403 Forbidden)');
    } else {
      throw Exception('Ошибка загрузки новелл: ${res.statusCode}');
    }
  }

  Future<void> addBookMultipart({
    required String title,
    required String author,
    String? description,
    File? coverFile,
  }) async {
    final uri = Uri.parse('$baseUrl/books');
    print('📡 [addBookMultipart] POST $uri');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);

    request.fields['title'] = title;
    request.fields['author'] = author;
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }

    print('📝 Fields: ${request.fields}');

    if (coverFile != null) {
      final length = await coverFile.length();
      final stream = http.ByteStream(coverFile.openRead());
      
      String ext = p.extension(coverFile.path).toLowerCase();
      MediaType contentType = MediaType('image', 'jpeg'); // default
      
      if (ext == '.png') {
        contentType = MediaType('image', 'png');
      } else if (ext == '.jpg' || ext == '.jpeg') {
        contentType = MediaType('image', 'jpeg');
      } else if (ext == '.webp') {
        contentType = MediaType('image', 'webp');
      }
      
      final multipartFile = http.MultipartFile(
        'cover',
        stream,
        length,
        filename: p.basename(coverFile.path),
        contentType: contentType,
      );
      request.files.add(multipartFile);
      print('🖼 Cover file: ${p.basename(coverFile.path)} (${length} bytes)');
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    print('📡 [addBookMultipart] STATUS: ${response.statusCode}');
    print('📦 [addBookMultipart] BODY: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      if (response.statusCode == 403) {
        throw Exception('Доступ запрещён (403 Forbidden)');
      }
      throw Exception('Ошибка добавления новеллы: ${response.statusCode} — ${response.body}');
    }
  }

  Future<void> deleteBook(int id) async {
    final url = Uri.parse('$baseUrl/books/$id');
    print('📡 [deleteBook] DELETE $url');
    final res = await http.delete(url, headers: headers);
    print('📦 [deleteBook] STATUS: ${res.statusCode}');
    if (res.statusCode != 200) {
      throw Exception('Ошибка удаления новеллы: ${res.statusCode}');
    }
  }

  Future<List<dynamic>> getUsers() async {
    final url = Uri.parse('$baseUrl/users');
    print('📡 [getUsers] GET $url');
    final res = await http.get(url, headers: headers);
    print('📡 [getUsers] STATUS: ${res.statusCode}');
    print('📦 [getUsers] BODY: ${res.body}');
    if (res.statusCode == 200) {
      if (res.body.isEmpty) return [];
      return jsonDecode(res.body);
    } else if (res.statusCode == 403) {
      throw Exception('Доступ запрещён (403 Forbidden)');
    } else {
      throw Exception('Ошибка загрузки пользователей: ${res.statusCode}');
    }
  }

  Future<void> deleteUser(int id) async {
    final url = Uri.parse('$baseUrl/users/$id');
    print('📡 [deleteUser] DELETE $url');
    final res = await http.delete(url, headers: headers);
    print('📡 [deleteUser] STATUS: ${res.statusCode}');
    if (res.statusCode != 200) {
      throw Exception('Ошибка удаления пользователя: ${res.statusCode}');
    }
  }

  Future<void> changeUserRole(int id, String newRole) async {
    final url = Uri.parse('$baseUrl/users/$id/role?role=$newRole');
    print('📡 [changeUserRole] PUT $url');
    final res = await http.put(url, headers: headers);
    print('📡 [changeUserRole] STATUS: ${res.statusCode}');
    if (res.statusCode != 200) {
      throw Exception('Ошибка изменения роли: ${res.statusCode}');
    }
  }
}