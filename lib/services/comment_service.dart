import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class CommentService {
  Future<List<Map<String, dynamic>>> getCommentsForChapter(
    String token,
    int chapterId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/comments/chapter/$chapterId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
    int chapterId,
    String content, {
    int? parentCommentId,
  }) async {
    try {
      final payload = {
        'bookId': bookId,
        'chapterId': chapterId,
        'content': content,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/comments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

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
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('Ошибка при удалении комментария: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка при удалении комментария: $e');
    }
  }
}
