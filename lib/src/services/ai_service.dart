import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static Future<String> checkInteraction(String med1, String med2) async {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer YOUR_API_KEY",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "user",
            "content":
                "Check if $med1 and $med2 have any dangerous interactions.",
          },
        ],
      }),
    );

    final data = jsonDecode(response.body);

    return data["choices"][0]["message"]["content"];
  }
}
