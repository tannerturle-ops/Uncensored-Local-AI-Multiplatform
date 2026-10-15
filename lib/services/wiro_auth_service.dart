import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Wiro project credentials never appear in source control or plain settings.
class WiroAuthService {
  static const _storage = FlutterSecureStorage();
  static const _apiKeyName = 'wiro_project_api_key';
  static const _secretName = 'wiro_project_secret_key';

  Future<bool> hasCredentials() async {
    final key = await _storage.read(key: _apiKeyName);
    final secret = await _storage.read(key: _secretName);
    return key != null && key.trim().isNotEmpty &&
        secret != null && secret.trim().isNotEmpty;
  }

  Future<void> saveCredentials({
    required String apiKey,
    required String secretKey,
  }) async {
    if (apiKey.trim().isEmpty || secretKey.trim().isEmpty) {
      throw ArgumentError('Both Wiro API key and secret key are required.');
    }
    await _storage.write(key: _apiKeyName, value: apiKey.trim());
    await _storage.write(key: _secretName, value: secretKey.trim());
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _apiKeyName);
    await _storage.delete(key: _secretName);
  }

  /// Wiro specifies HMAC-SHA256(key=API_KEY, message=API_SECRET + NONCE).
  Future<Map<String, String>> signedHeaders() async {
    final key = await _storage.read(key: _apiKeyName);
    final secret = await _storage.read(key: _secretName);
    if (key == null || key.isEmpty || secret == null || secret.isEmpty) {
      throw StateError('Save your Wiro API and secret keys in Settings first.');
    }
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final signature = Hmac(sha256, utf8.encode(key))
        .convert(utf8.encode('$secret$nonce'))
        .toString();
    return {
      'x-api-key': key,
      'x-nonce': nonce,
      'x-signature': signature,
    };
  }

  /// Read-only model metadata request: never starts a billable task.
  Future<void> testConnection() async {
    final response = await http.post(
      Uri.parse('https://api.wiro.ai/v1/Tool/Detail'),
      headers: {
        ...await signedHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'slugowner': 'bytedance',
        'slugproject': 'seedream-v5-lite-uncensored',
      }),
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Wiro rejected the project credentials (HTTP ${response.statusCode}).');
    }
    if (response.statusCode != 200) {
      throw StateError('Wiro returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['result'] != true) {
      throw StateError('Wiro could not verify model access: ${decoded is Map ? decoded['errors'] : 'invalid response'}');
    }
  }

}
