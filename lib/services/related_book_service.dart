import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:prosper/constants/api_constants.dart';

class RelatedBookService {
  // ApiConstants.baseUrl already contains '/api', so we append '/related-books/...'
  // NOT '/api/related-books/...' — that would double the /api segment.

  Future<List<dynamic>> getRelatedBooks(String token, int bookId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/related-books/$bookId');
    debugPrint('[RelatedBookService] GET $url');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('[RelatedBookService] getRelatedBooks → ${response.statusCode} | body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Не авторизован');
      } else {
        throw Exception('Ошибка загрузки связанных новелл: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[RelatedBookService] getRelatedBooks exception: $e');
      throw Exception('Ошибка: $e');
    }
  }

  Future<void> addRelatedBook(
    String token,
    int bookId,
    int relatedBookId,
    String relationType,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/related-books');
    final payload = {
      'bookId': bookId,
      'relatedBookId': relatedBookId,
      'relationType': relationType,
    };
    debugPrint('[RelatedBookService] POST $url | payload: $payload');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('[RelatedBookService] addRelatedBook → ${response.statusCode} | body: ${response.body}');

      if (response.statusCode != 201) {
        throw Exception('Ошибка добавления связи: ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      debugPrint('[RelatedBookService] addRelatedBook exception: $e');
      throw Exception('Ошибка: $e');
    }
  }

  // Delete by relation row ID — safe for both normal and reversed relations.
  Future<void> deleteRelatedBookById(String token, int relationId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/related-books/$relationId');
    debugPrint('[RelatedBookService] DELETE by id $url');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      debugPrint('[RelatedBookService] deleteById → ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Ошибка удаления связи: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[RelatedBookService] deleteById exception: $e');
      throw Exception('Ошибка: $e');
    }
  }

  // Legacy: delete by book pair (kept for compatibility).
  Future<void> deleteRelatedBook(
    String token,
    int bookId,
    int relatedBookId,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/related-books/$bookId/$relatedBookId');
    debugPrint('[RelatedBookService] DELETE $url');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      debugPrint('[RelatedBookService] deleteRelatedBook → ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Ошибка удаления связи: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[RelatedBookService] deleteRelatedBook exception: $e');
      throw Exception('Ошибка: $e');
    }
  }
}
