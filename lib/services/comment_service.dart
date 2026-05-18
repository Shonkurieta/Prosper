import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class CommentService {

  Future<List<Map<String, dynamic>>> getCommentsForChapter(
    String token,
    int chapterId,
  ) async {
    final url = '${ApiConstants.baseUrl}/comments/chapter/$chapterId';

    print('>>> [CommentService] GET $url');
    print('>>> [CommentService] TOKEN EMPTY: ${token.isEmpty}');
    print('>>> [CommentService] TOKEN (20): ${token.length >= 20 ? token.substring(0, 20) : token}');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('<<< [CommentService] STATUS: ${response.statusCode}');
      print('<<< [CommentService] BODY: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Ошибка загрузки комментариев: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка при загрузке комментариев: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCommentsForBook(
    String token,
    int bookId,
  ) async {
    final url = '${ApiConstants.baseUrl}/comments/book/$bookId';

    print('>>> [CommentService] GET $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('<<< [CommentService] STATUS: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Ошибка загрузки комментариев: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка при загрузке комментариев: $e');
    }
  }

  Future<Map<String, dynamic>> addComment(
    String token,
    int bookId,
    int? chapterId,
    String content, {
    int? parentCommentId,
  }) async {
    final url = '${ApiConstants.baseUrl}/comments';

    print('>>> [CommentService] POST $url');
    print('>>> [CommentService] TOKEN EMPTY: ${token.isEmpty}');
    print('>>> [CommentService] TOKEN (20): ${token.length >= 20 ? token.substring(0, 20) : token}');

    try {
      final payload = {
        'bookId': bookId,
        'chapterId': chapterId,
        'content': content,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      };

      print('>>> [CommentService] PAYLOAD: $payload');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('<<< [CommentService] STATUS: ${response.statusCode}');
      print('<<< [CommentService] BODY: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка при добавлении комментария: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка при добавлении комментария: $e');
    }
  }

  Future<void> deleteComment(
    String token,
    int commentId,
  ) async {
    final url = '${ApiConstants.baseUrl}/comments/$commentId';

    print('>>> [CommentService] DELETE $url');
    print('>>> [CommentService] TOKEN EMPTY: ${token.isEmpty}');

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('<<< [CommentService] STATUS: ${response.statusCode}');
      print('<<< [CommentService] BODY: ${response.body}');

      if (response.statusCode != 204) {
        throw Exception('Ошибка при удалении комментария: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка при удалении комментария: $e');
    }
  }
}
