import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../config/openrouter_config.dart';

class OpenRouterAuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _verifierKey = 'openrouter_code_verifier';
  static const String _apiKeyKey = 'openrouter_api_key';

  // Generate a random code verifier (public for WebView flow)
  String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  // Generate code challenge from verifier (public for WebView flow)
  String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  // Store verifier for later use
  Future<void> storeVerifier(String verifier) async {
    await _storage.write(key: _verifierKey, value: verifier);
  }

  // Exchange code for API key
  Future<String?> exchangeCode(String code) async {
    final verifier = await _storage.read(key: _verifierKey);
    if (verifier == null) {
      throw Exception('No code verifier found. Did you start the auth flow?');
    }

    final response = await http.post(
      Uri.parse(OpenRouterConfig.tokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'code_verifier': verifier,
        'code_challenge_method': 'S256',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final key = data['key'] as String?;
      
      if (key != null) {
        // Store API key securely
        await _storage.write(key: _apiKeyKey, value: key);
        // Clear verifier
        await _storage.delete(key: _verifierKey);
        return key;
      } else {
        throw Exception('Response did not contain API key');
      }
    } else {
      throw Exception('Failed to exchange code: ${response.body}');
    }
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }
  
  Future<void> logout() async {
    await _storage.delete(key: _apiKeyKey);
  }
}
