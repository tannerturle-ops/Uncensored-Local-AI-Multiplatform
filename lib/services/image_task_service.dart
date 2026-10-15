import 'dart:convert';
import 'dart:typed_data';

import '../models/message_model.dart';
import 'image_attachment_service.dart';
import 'image_provider.dart';

/// Provider-neutral image orchestration. Never degrades an edit into generation.
class ImageTaskService {
  ImageTaskService({ImageProvider? provider}) : _provider = provider;

  ImageProvider? _provider;
  final _attachments = ImageAttachmentService();

  bool get isConfigured => _provider != null;
  String? get providerName => _provider?.displayName;

  void configure(ImageProvider provider) => _provider = provider;
  void disconnect() => _provider = null;

  Future<MessageModel> create(String prompt) async {
    final provider = _provider;
    if (provider == null) {
      throw StateError('Add an image provider in Settings before generating images.');
    }
    if (!provider.supports(ImageCapability.textToImage)) {
      throw UnsupportedError('${provider.displayName} does not support image generation.');
    }
    final result = await provider.generate(ImageRequest(prompt: prompt));
    return _storeResult(result, sourceImageId: null);
  }

  Future<MessageModel> edit({
    required String prompt,
    required MessageModel source,
  }) async {
    final provider = _provider;
    if (provider == null) {
      throw StateError('Add an image provider in Settings before editing images.');
    }
    if (!provider.supports(ImageCapability.imageEditing) ||
        !provider.supports(ImageCapability.referenceImages)) {
      throw UnsupportedError(
        '${provider.displayName} cannot edit source images. '
        'Choose a provider with image editing and reference-image support.',
      );
    }

    // An edit must have real source bytes. No text-only fallback.
    Uint8List bytes;
    if (source.imageLocalPath != null) {
      final file = await _attachments.resolve(source.imageLocalPath);
      if (file == null) throw StateError('The original image is missing.');
      bytes = await file.readAsBytes();
    } else if (source.imageBase64 != null) {
      bytes = base64Decode(source.imageBase64!);
    } else {
      throw StateError('The selected message does not contain an editable image.');
    }
    if (bytes.isEmpty) throw StateError('The original image is empty.');

    final result = await provider.edit(ImageRequest(
      prompt: 'Edit the provided image: $prompt. Preserve the original '
          'subject identity, face, pose, composition and background except '
          'for changes explicitly requested.',
      referenceImages: [bytes],
    ));
    return _storeResult(result, sourceImageId: source.imageId);
  }

  Future<MessageModel> _storeResult(
    ImageResult result, {
    String? sourceImageId,
  }) async {
    final fileName = await _attachments.save(
      bytes: result.bytes,
      mimeType: result.mimeType,
    );
    return MessageModel(
      role: MessageRole.assistant,
      content: '',
      imageLocalPath: fileName,
      imageMimeType: result.mimeType,
      imageId: fileName,
      sourceImageId: sourceImageId,
      imageProvider: result.providerId,
      imagePrompt: result.prompt,
    );
  }
}
