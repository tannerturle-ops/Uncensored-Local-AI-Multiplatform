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

  /// A read-only signed call: does not create a billable image task.
  Future<void> testConnection() async {
    final response = await http.post(
      Uri.parse('https://api.wiro.ai/v1/Task/Detail'),
      headers: {
        ...await signedHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'taskid': '0'}),
    ).timeout(const Duration(seconds: 20));
    // Task 0 usually does not exist. It is still proof the credentials were
    // accepted if the API returns a non-auth failure. Treat 401/403 as failure.
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Wiro rejected the project credentials (HTTP ${response.statusCode}).');
    }
    if (response.statusCode >= 500) {
      throw StateError('Wiro is unavailable (HTTP ${response.statusCode}).');
    }
    if (response.statusCode != 200) {
      throw StateError('Wiro verification returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['result'] == false) {
      // Wiro can return result:false even for invalid task IDs. This is not
      // guaranteed to distinguish account auth from a missing task.
      throw StateError('Wiro responded, but credentials could not be verified without a valid task.');
    }
  }
}
