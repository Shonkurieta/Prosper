import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:prosper/constants/api_constants.dart';

class RelatedBookService {
  Future<List<dynamic>> getRelatedBooks(String token, int bookId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/related-books/$bookId'),
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
        throw Exception('Ошибка загрузки связанных новелл');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<void> addRelatedBook(
    String token,
    int bookId,
    int relatedBookId,
    String relationType,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/related-books'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bookId': bookId,
          'relatedBookId': relatedBookId,
          'relationType': relationType,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Ошибка добавления связи');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<void> deleteRelatedBook(
    String token,
    int bookId,
    int relatedBookId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/related-books/$bookId/$relatedBookId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка удаления связи');
      }
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }
}
