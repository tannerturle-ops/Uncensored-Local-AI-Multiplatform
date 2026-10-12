import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Optional OpenAI-compatible vision endpoint. Distinct from DeepSeek text.
/// Never forwards an image to a model that only accepts text.
class VisionService {
  static const _vault = FlutterSecureStorage();
  static const _key = 'mochi_vision_api_key';
  static const _url = 'mochi_vision_endpoint';
  static const _model = 'mochi_vision_model';

  Future<bool> get isConfigured async =>
      (await _vault.read(key: _key))?.isNotEmpty == true &&
      (await _vault.read(key: _url))?.isNotEmpty == true &&
      (await _vault.read(key: _model))?.isNotEmpty == true;

  Future<void> configure({
    required String endpoint,
    required String model,
    required String apiKey,
  }) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError('Use an HTTPS chat-completions endpoint.');
    }
    if (model.trim().isEmpty || apiKey.trim().isEmpty) {
      throw ArgumentError('Vision model and API key are required.');
    }
    await _vault.write(key: _url, value: endpoint.trim());
    await _vault.write(key: _model, value: model.trim());
    await _vault.write(key: _key, value: apiKey.trim());
  }

  Future<void> clear() async {
    await _vault.delete(key: _url);
    await _vault.delete(key: _model);
    await _vault.delete(key: _key);
  }

  Future<String> describe({
    required Uint8List image,
    required String mimeType,
    required String prompt,
  }) async {
    if (!await isConfigured) {
      throw StateError('Set up a vision-capable model in Images & Media settings.');
    }
    final endpoint = (await _vault.read(key: _url))!;
    final model = (await _vault.read(key: _model))!;
    final key = (await _vault.read(key: _key))!;
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'stream': false,
        'messages': [{
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt.isEmpty ? 'Describe this image.' : prompt},
            {'type': 'image_url', 'image_url': {'url': 'data:$mimeType;base64,${base64Encode(image)}'}},
          ],
        }],
      }),
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      throw StateError('Vision API returned HTTP ${response.statusCode}.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('Vision API returned no answer.');
    }
    final content = (choices.first as Map)['message']?['content'];
    if (content is String && content.trim().isNotEmpty) return content;
    if (content is List) {
      final answer = content.whereType<Map>().map((p) => p['text']?.toString() ?? '').join('\n');
      if (answer.trim().isNotEmpty) return answer;
    }
    throw StateError('Vision API returned an unsupported answer.');
  }
}
