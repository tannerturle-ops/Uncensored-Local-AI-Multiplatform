import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Optional cloud provider. Local GGUF inference remains independent of this.
class DeepSeekService {
  static const String chatModel = 'deepseek-flash';
  static const String reasonerModel = 'deepseek-v4-pro';
  static const String chatId = 'cloud:$chatModel';
  static const String reasonerId = 'cloud:$reasonerModel';

  static bool isCloud(String? id) => id?.startsWith('cloud:') ?? false;
  static String modelFromId(String id) => id.substring('cloud:'.length);

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'deepseek_api_key';

  Future<bool> hasKey() async {
    final key = await _storage.read(key: _keyName);
    return key != null && key.trim().isNotEmpty;
  }

  Future<void> saveKey(String key) async {
    if (key.trim().isEmpty) {
      await _storage.delete(key: _keyName);
    } else {
      await _storage.write(key: _keyName, value: key.trim());
    }
  }

  Future<void> clearKey() => _storage.delete(key: _keyName);

  /// Returns the final response text. No key is sent anywhere except DeepSeek.
  Future<String> complete({
    required String model,
    required List<Map<String, String>> messages,
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    final key = await _storage.read(key: _keyName);
    if (key == null || key.isEmpty) {
      throw StateError('Add your DeepSeek API key in Settings first.');
    }
    final payload = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];
    final response = await http.post(
      Uri.parse('https://api.deepseek.com/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': model,
        'messages': payload,
        'stream': false,
        'temperature': temperature,
      }),
    ).timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) {
      // Never include response bodies: providers may echo request information.
      throw StateError('DeepSeek request failed (HTTP ${response.statusCode}). Check your API key, model access, or network.');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final msg = choices?.isNotEmpty == true
        ? (choices!.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?
        : null;
    final result = msg?['content'] as String?;
    if (result == null || result.trim().isEmpty) {
      throw StateError('DeepSeek returned an empty response.');
    }
    return result;
  }
}
