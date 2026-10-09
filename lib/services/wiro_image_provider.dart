import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'image_provider.dart';
import 'wiro_auth_service.dart';

/// Seedream adapter. Only this class understands Wiro's API/task protocol.
class WiroImageProvider implements ImageProvider {
  WiroImageProvider({WiroAuthService? auth})
      : _auth = auth ?? WiroAuthService();

  final WiroAuthService _auth;
  static const _base = 'https://api.wiro.ai/v1';
  static const _model = 'seedream-v5-lite-uncensored';

  @override
  String get id => 'wiro';
  @override
  String get displayName => 'Wiro AI · Seedream 5.0 Lite';
  @override
  Set<ImageCapability> get capabilities => {
    ImageCapability.textToImage,
    ImageCapability.imageEditing,
    ImageCapability.referenceImages,
  };

  @override
  bool supports(ImageCapability capability) => capabilities.contains(capability);

  @override
  Future<ImageResult> generate(ImageRequest request) => _run(request);

  @override
  Future<ImageResult> edit(ImageRequest request) async {
    if (request.referenceImages.isEmpty) {
      throw StateError('Image edits require the original image.');
    }
    return _run(request);
  }

  Future<ImageResult> _run(ImageRequest request) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$_base/Run/bytedance/$_model');
      http.Response response;
      if (request.referenceImages.isEmpty) {
        response = await client.post(uri,
          headers: {
            ...await _auth.signedHeaders(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'prompt': request.prompt,
            'maxImages': 1,
            'watermark': 'false',
            'resolution': request.resolution ?? '2k',
            'aspectRatio': request.aspectRatio ?? '1:1',
          }),
        ).timeout(const Duration(seconds: 45));
      } else {
        // Wiro accepts multipart files under the model's inputImage field.
        final multipart = http.MultipartRequest('POST', uri);
        multipart.headers.addAll(await _auth.signedHeaders());
        multipart.fields.addAll({
          'prompt': request.prompt,
          'maxImages': '1',
          'watermark': 'false',
        });
        for (var i = 0; i < request.referenceImages.length; i++) {
          multipart.files.add(http.MultipartFile.fromBytes(
            'inputImage',
            request.referenceImages[i],
            filename: 'reference_$i.png',
          ));
        }
        final streamed = await client.send(multipart)
            .timeout(const Duration(seconds: 45));
        response = await http.Response.fromStream(streamed);
      }

      final run = _checkedResponse(response, 'start');
      final token = run['socketaccesstoken']?.toString();
      final taskId = run['taskid']?.toString();
      if ((token == null || token.isEmpty) && (taskId == null || taskId.isEmpty)) {
        throw StateError('Wiro did not return a task identifier.');
      }

      // Poll the same paid task. Do not resubmit a new generation.
      final deadline = DateTime.now().add(const Duration(minutes: 4));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 3));
        final detailResponse = await client.post(
          Uri.parse('$_base/Task/Detail'),
          headers: {
            ...await _auth.signedHeaders(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(token != null && token.isNotEmpty
              ? {'tasktoken': token}
              : {'taskid': taskId}),
        ).timeout(const Duration(seconds: 30));
        final detail = _checkedResponse(detailResponse, 'status');
        final tasks = detail['tasklist'];
        if (tasks is! List || tasks.isEmpty || tasks.first is! Map) {
          continue;
        }
        final task = tasks.first as Map;
        final status = task['status']?.toString() ?? '';
        if (status == 'task_cancel' || status == 'task_cancelled') {
          throw StateError('Wiro cancelled the image generation.');
        }
        if (status != 'task_postprocess_end') continue;
        if (task['pexit']?.toString() != '0') {
          throw StateError('Wiro image generation failed: ${task['debugoutput'] ?? task['pexit']}');
        }
        final outputs = task['outputs'];
        if (outputs is! List || outputs.isEmpty || outputs.first is! Map) {
          throw StateError('Wiro completed without an output image.');
        }
        final output = outputs.first as Map;
        final url = output['url']?.toString();
        if (url == null || !url.startsWith('https://')) {
          throw StateError('Wiro returned an invalid output URL.');
        }
        final downloaded = await client.get(Uri.parse(url))
            .timeout(const Duration(seconds: 60));
        if (downloaded.statusCode != 200) {
          throw StateError('Could not download the generated image.');
        }
        final mime = downloaded.headers['content-type']
            ?.split(';').first.trim() ?? 'image/png';
        final supportedMime = const {'image/png', 'image/jpeg', 'image/webp', 'image/gif'};
        return ImageResult(
          bytes: Uint8List.fromList(downloaded.bodyBytes),
          mimeType: supportedMime.contains(mime) ? mime : 'image/png',
          providerId: id,
          modelId: _model,
          prompt: request.prompt,
          estimatedCostUsd: 0.035,
        );
      }
      throw TimeoutException(
        'Wiro is taking longer than four minutes. Check your Wiro task history before retrying.');
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _checkedResponse(http.Response response, String phase) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Wiro authentication failed. Check your saved keys.');
    }
    if (response.statusCode != 200) {
      throw StateError('Wiro $phase request failed (HTTP ${response.statusCode}).');
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic> || json['result'] != true) {
      throw StateError('Wiro $phase request failed: ${json is Map ? json['errors'] : response.body}');
    }
    return json;
  }
}
