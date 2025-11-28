import 'dart:convert';
import 'package:http/http.dart' as http;
import 'openrouter_auth_service.dart';

class OpenRouterClient {
  final OpenRouterAuthService _authService;
  final http.Client _httpClient;
  
  OpenRouterClient({
    OpenRouterAuthService? authService,
    http.Client? httpClient,
  }) : _authService = authService ?? OpenRouterAuthService(),
       _httpClient = httpClient ?? http.Client();

  Future<Map<String, dynamic>> chatCompletion({
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final apiKey = await _authService.getApiKey();
    if (apiKey == null) {
      throw Exception('Not authenticated. Please log in.');
    }

    final response = await _httpClient.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/imagineapp', // Optional but recommended
        'X-Title': 'Imagine App', // Optional but recommended
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get completion: ${response.body}');
    }
  }
}

