import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ReviewService {
  final String baseUrl = ApiConstants.baseUrl;

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<List<dynamic>> getReviewsByBook(String token, int bookId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reviews/book/$bookId'),
      headers: _headers(token),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load reviews');
  }

  Future<List<dynamic>> getRecentReviews(String token, {int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reviews/recent?limit=$limit'),
      headers: _headers(token),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load recent reviews');
  }

  Future<Map<String, dynamic>> createReview({
    required String token,
    required int bookId,
    required String title,
    required String content,
    required String type,
    required int rating,
    required String sentiment,
  }) async {
    final Map<String, dynamic> body = {
      'bookId': bookId,
      'title': title,
      'content': content,
      'type': type,
      'rating': rating,
      'sentiment': sentiment,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/reviews'),
      headers: _headers(token),
      body: json.encode(body),
    );

    if (response.statusCode == 200) return json.decode(response.body);
    try {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Ошибка при создании отзыва');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Ошибка сервера: ${response.statusCode}');
    }
  }

  Future<void> deleteReview(String token, int reviewId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/reviews/$reviewId'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) throw Exception('Failed to delete review');
  }

  Future<void> toggleLike(String token, int reviewId, bool isLike) async {
    await http.post(
      Uri.parse('$baseUrl/reviews/$reviewId/like'),
      headers: _headers(token),
      body: json.encode({'isLike': isLike}),
    );
  }

  Future<bool> recordView(String token, int reviewId) async {
    if (token.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reviews/$reviewId/view'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isNew'] == true;
      }
    } catch (_) {}
    return false;
  }
}
