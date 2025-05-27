import 'package:http/http.dart' as http;
import 'dart:convert';

class GeminiService {
  final String apiKey;

  GeminiService({required this.apiKey});

  Future<String> chatWithGemini(String prompt) async {
    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=$apiKey",
    );

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["candidates"][0]["content"]["parts"][0]["text"];
    } else {
      return "Error al comunicarse con el servidor";
    }
  }
}
