import 'dart:async';
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

  /// Streams text deltas from DeepSeek's Server-Sent Events API.
  /// Cancelling the subscription closes the underlying HTTP client.
  Stream<String> streamCompletion({
    required String model,
    required List<Map<String, String>> messages,
    String? systemPrompt,
    double temperature = 0.7,
  }) async* {
    final key = await _storage.read(key: _keyName);
    if (key == null || key.isEmpty) {
      throw StateError('Add your DeepSeek API key in Settings first.');
    }
    final payload = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];
    final client = http.Client();
    try {
      final req = http.Request('POST',
          Uri.parse('https://api.deepseek.com/chat/completions'));
      req.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'Accept': 'text/event-stream',
      });
      req.body = jsonEncode({
        'model': model,
        'messages': payload,
        'stream': true,
        'temperature': temperature,
      });
      final response = await client.send(req)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        // Avoid exposing API keys or user prompts in failure messages.
        final reason = switch (response.statusCode) {
          400 => 'The selected DeepSeek model or request was rejected.',
          401 => 'Your DeepSeek API key was rejected.',
          402 => 'Your DeepSeek account may need more API credit.',
          403 => 'Access to this model was denied.',
          404 => 'The DeepSeek model or endpoint was not found.',
          429 => 'DeepSeek is rate-limiting requests.',
          >= 500 => 'DeepSeek is temporarily unavailable.',
          _ => 'Please check your API key and connection.',
        };
        throw StateError('DeepSeek HTTP ${response.statusCode}: $reason');
      }
      // The connect timeout above does not protect against a server that
      // opens an SSE connection but then sends no more data.
      var receivedText = false;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(
            const Duration(seconds: 60),
            onTimeout: (sink) => sink.addError(
              TimeoutException('No data received from DeepSeek for 60 seconds. '
                'Please retry or select another model.')),
          )) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') break;
        if (data.isEmpty) continue;
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map<String, dynamic>)['delta']
            as Map<String, dynamic>?;
        final part = delta?['content'];
        if (part is String && part.isNotEmpty) {
          receivedText = true;
          yield part;
        }
      }
      if (!receivedText) {
        throw StateError('DeepSeek returned no text. Check your selected model, '
          'API access, or try again.');
      }
    } on TimeoutException catch (error) {
      throw StateError('DeepSeek timed out: ${error.message}');
    } finally {
      client.close();
    }
  }
}
