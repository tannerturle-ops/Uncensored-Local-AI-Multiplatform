import 'dart:typed_data';

/// All providers implement the same contract; model/provider choices are
/// independent of the selected text-chat model.
enum ImageCapability {
  textToImage,
  imageEditing,
  referenceImages,
  multipleReferences,
  inpainting,
  upscaling,
}

class ImageRequest {
  final String prompt;
  final String? model;
  final String? aspectRatio;
  final String? resolution;
  final List<Uint8List> referenceImages;

  const ImageRequest({
    required this.prompt,
    this.model,
    this.aspectRatio,
    this.resolution,
    this.referenceImages = const [],
  });
}

class ImageResult {
  final Uint8List bytes;
  final String mimeType;
  final String providerId;
  final String? modelId;
  final String prompt;
  final double? estimatedCostUsd;

  const ImageResult({
    required this.bytes,
    required this.mimeType,
    required this.providerId,
    required this.prompt,
    this.modelId,
    this.estimatedCostUsd,
  });
}

/// Adapter implemented separately for each cloud image API.
/// Providers may return tasks asynchronously internally, but the chat layer
/// receives one completed ImageResult regardless of implementation.
abstract class ImageProvider {
  String get id;
  String get displayName;
  Set<ImageCapability> get capabilities;

  bool supports(ImageCapability capability) =>
      capabilities.contains(capability);

  Future<ImageResult> generate(ImageRequest request);

  Future<ImageResult> edit(ImageRequest request) {
    throw UnsupportedError('$displayName does not support image editing.');
  }
}
