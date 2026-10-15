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

  /// Checks key/account access without invoking a chat model or streaming.
  /// This distinguishes authentication/connectivity from model-generation failures.
  Future<String> testAuthentication() async {
    final key = await _storage.read(key: _keyName);
    if (key == null || key.trim().isEmpty) {
      throw StateError('No DeepSeek API key saved on this device.');
    }
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse('https://api.deepseek.com/models'),
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return 'DeepSeek key accepted. Model generation was not tested.';
      }
      final explanation = switch (response.statusCode) {
        401 => 'Invalid or expired API key.',
        402 => 'DeepSeek billing or credits issue.',
        403 => 'This key does not have permission to access DeepSeek.',
        429 => 'Too many requests; try again later.',
        >= 500 => 'DeepSeek server error. Try again later.',
        _ => 'The DeepSeek API rejected this request.',
      };
      throw StateError('HTTP ${response.statusCode}: $explanation');
    } on TimeoutException {
      throw StateError('Connection timed out. Check your network or VPN.');
    } finally {
      client.close();
    }
  }

  /// Tiny non-streaming diagnostic. Unlike the key check, this tests
  /// real model generation and reports failures without exposing secrets.
  Future<String> testTextGeneration(String model) async {
    if (model != chatModel && model != reasonerModel) {
      throw ArgumentError('Unsupported DeepSeek test model.');
    }
    final key = await _storage.read(key: _keyName);
    if (key == null || key.trim().isEmpty) {
      throw StateError('No DeepSeek API key saved.');
    }
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse('https://api.deepseek.com/chat/completions'),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': 'Reply with exactly OK.'},
          ],
          'stream': false,
          'thinking': {'type': 'disabled'},
          'max_tokens': 32,
        }),
      ).timeout(const Duration(seconds: 75));
      if (response.statusCode != 200) {
        String detail = '';
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final failure = data['error'];
          if (failure is Map) {
            detail = (failure['message'] ?? failure['code'] ?? '').toString();
          }
        } catch (_) {}
        // Use a bounded server message, never reflect credentials.
        if (detail.length > 240) detail = detail.substring(0, 240);
        if (detail.toLowerCase().contains(key.toLowerCase())) detail = '';
        throw StateError('DeepSeek $model returned HTTP ${response.statusCode}'
            '${detail.isEmpty ? '' : ': $detail'}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        throw StateError('$model returned HTTP 200 but no choices.');
      }
      final message = (choices.first as Map)['message'];
      final answer = message is Map ? message['content'] : null;
      if (answer is! String || answer.trim().isEmpty) {
        throw StateError('$model returned HTTP 200 but empty content.');
      }
      return '$model generated: ${answer.trim()}';
    } on TimeoutException {
      throw StateError('$model generation timed out after 75 seconds.');
    } finally {
      client.close();
    }
  }

  /// Streams text deltas from DeepSeek's Server-Sent Events API.
  /// Cancelling the subscription closes the underlying HTTP client.
  Stream<String> streamCompletion({
    required String model,
    required List<Map<String, String>> messages,
    String? systemPrompt,
    double temperature = 0.7,
    String reasoningEffort = 'high',
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
        'thinking': {'type': reasoningEffort == 'off' ? 'disabled' : 'enabled'},
        if (reasoningEffort != 'off')
          'reasoning_effort': {'low', 'high', 'max'}.contains(reasoningEffort)
              ? reasoningEffort : 'high',
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
