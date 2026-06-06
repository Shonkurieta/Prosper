import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prosper/constants/api_constants.dart';

class RecommendationService {
  Future<Map<String, dynamic>> getRecommendations(
    String token, {
    int limit = 10,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/recommendations?limit=$limit'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'books': <dynamic>[], 'level': 0};
  }
}
