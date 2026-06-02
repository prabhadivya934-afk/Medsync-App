import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  // ✅ Replace with your Render URL
  static const String baseUrl = "https://medsync-app-1.onrender.com";

  static Future<void> sendSkipAlert({
    required List<String> numbers,
    required String medicineName,
    required String time,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/send-skip-alert"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "numbers": numbers,
        "medicineName": medicineName,
        "time": time,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to send SMS");
    }
  }
}
