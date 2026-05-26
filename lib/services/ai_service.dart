import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class AiService {
  static Future<Map<String, dynamic>> sendMessage({
    required String token,
    required String question,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/ai/chat');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'question': question,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to get AI response: ${response.statusCode}');
    }
  }
}