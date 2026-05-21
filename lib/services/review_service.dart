import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ReviewService {
  final String baseUrl = ApiConstants.baseUrl;

  Future<List<dynamic>> getReviewsByBook(String token, int bookId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reviews/book/$bookId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load reviews');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createReview({
    required String token,
    required int bookId,
    required String content,
    required String type,
    required int rating,
    required String sentiment,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'bookId': bookId,
        'content': content,
        'type': type,
        'rating': rating,
        'sentiment': sentiment,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['message'] ?? 'Ошибка при создании отзыва');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Ошибка сервера: ${response.statusCode}');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteReview(String token, int reviewId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/reviews/$reviewId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete review');
      }
    } catch (e) {
      rethrow;
    }
  }
}
