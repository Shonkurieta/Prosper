
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import '../constants/api_constants.dart';
import '../models/genre.dart';

class AdminService {
  static final String baseUrl = ApiConstants.adminUrl;

  final String token;

  AdminService(this.token);

  Map<String, String> get headers => {
        'Authorization': 'Bearer $token',
      };

  // === ЖАНРЫ ===

  Future<List<Genre>> getGenres() async {
    final url = Uri.parse('$baseUrl/genres');
    print('📡 [getGenres] GET $url');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
      return data.map((json) => Genre.fromJson(json)).toList();
    } else {
      throw Exception('Ошибка загрузки жанров: ${res.statusCode}');
    }
  }

  // === НОВЕЛЛЫ ===

  Future<List<dynamic>> getBooks() async {
    final url = Uri.parse('$baseUrl/books');
    print('📡 [getBooks] GET $url');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      if (res.body.isEmpty) return [];
      return jsonDecode(utf8.decode(res.bodyBytes));
    } else {
      throw Exception('Ошибка загрузки новелл: ${res.statusCode}');
    }
  }

  Future<void> addBookMultipart({
    required String title,
    required String author,
    String? description,
    required List<String> genres,
    File? coverFile,
  }) async {
    final uri = Uri.parse('$baseUrl/books');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);

    request.fields['title'] = title;
    request.fields['author'] = author;
    request.fields['description'] = description ?? '';
    request.fields['genres'] = genres.join(',');

    if (coverFile != null) {
      final length = await coverFile.length();
      final stream = http.ByteStream(coverFile.openRead());
      
      String ext = p.extension(coverFile.path).toLowerCase();
      MediaType contentType = MediaType('image', 'jpeg');
      if (ext == '.png') contentType = MediaType('image', 'png');
      
      final multipartFile = http.MultipartFile(
        'cover',
        stream,
        length,
        filename: p.basename(coverFile.path),
        contentType: contentType,
      );
      request.files.add(multipartFile);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка добавления новеллы: ${response.statusCode}');
    }
  }

  Future<void> updateBookMultipart({
    required int bookId,
    required String title,
    required String author,
    String? description,
    required List<String> genres,
    File? coverFile,
  }) async {
    final uri = Uri.parse('$baseUrl/books/$bookId');
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(headers);

    request.fields['title'] = title;
    request.fields['author'] = author;
    request.fields['description'] = description ?? '';
    request.fields['genres'] = genres.join(',');

    if (coverFile != null) {
      final length = await coverFile.length();
      final stream = http.ByteStream(coverFile.openRead());
      
      String ext = p.extension(coverFile.path).toLowerCase();
      MediaType contentType = MediaType('image', 'jpeg');
      if (ext == '.png') contentType = MediaType('image', 'png');
      
      final multipartFile = http.MultipartFile(
        'cover',
        stream,
        length,
        filename: p.basename(coverFile.path),
        contentType: contentType,
      );
      request.files.add(multipartFile);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Ошибка обновления новеллы: ${response.statusCode}');
    }
  }

  Future<void> deleteBook(int id) async {
    final url = Uri.parse('$baseUrl/books/$id');
    final res = await http.delete(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Ошибка удаления новеллы: ${res.statusCode}');
    }
  }

  // === ГЛАВЫ ===

  Future<void> addChapter(int bookId, String title, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books/$bookId/chapters'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'title': title,
        'content': content,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка при добавлении главы');
    }
  }

  Future<void> updateChapter(int bookId, int chapterId, String title, String content, int order) async {
    final response = await http.put(
      Uri.parse('$baseUrl/books/$bookId/chapters/$chapterId'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'title': title,
        'content': content,
        'chapterOrder': order,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка при обновлении главы');
    }
  }

  Future<void> deleteChapter(int bookId, int chapterId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/books/$bookId/chapters/$chapterId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка при удалении главы');
    }
  }

  // === ПОЛЬЗОВАТЕЛИ ===

  Future<List<dynamic>> getUsers() async {
    final url = Uri.parse('$baseUrl/users');
    final res = await http.get(url, headers: headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } else {
      throw Exception('Ошибка загрузки пользователей');
    }
  }

  Future<void> deleteUser(int id) async {
    final url = Uri.parse('$baseUrl/users/$id');
    final res = await http.delete(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Ошибка удаления пользователя: ${res.statusCode}');
    }
  }

  Future<void> updateUserRole(int userId, String newRole) async {
    final url = Uri.parse('$baseUrl/users/$userId/role');
    final res = await http.put(
      url,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'role': newRole,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка обновления роли пользователя: ${res.statusCode}');
    }
  }
}
