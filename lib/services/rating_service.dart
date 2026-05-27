import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class RatingService {
  static Future<Map<String, dynamic>> getRating(String token, int bookId) async {
    final url = '${ApiConstants.baseUrl}/books/$bookId/rating';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Ошибка загрузки оценки: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> rateBook(String token, int bookId, int rating) async {
    final url = '${ApiConstants.baseUrl}/books/$bookId/rating';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'rating': rating}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Ошибка сохранения оценки: ${response.statusCode}');
  }
}
