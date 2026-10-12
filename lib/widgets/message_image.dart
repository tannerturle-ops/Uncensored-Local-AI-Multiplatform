import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../models/message_model.dart';
import '../services/image_attachment_service.dart';

/// Full-screen images, image actions, and legacy inline image support.
class MessageImage extends StatelessWidget {
  const MessageImage({
    super.key,
    required this.message,
    this.onEdit,
    this.onRetry,
  });

  final MessageModel message;
  final VoidCallback? onEdit;
  final VoidCallback? onRetry;

  Future<File?> _sourceFile() async {
    if (message.imageLocalPath != null) {
      return ImageAttachmentService().resolve(message.imageLocalPath);
    }
    if (message.imageBase64 != null) {
      try {
        final bytes = base64Decode(message.imageBase64!);
        final name = await ImageAttachmentService().save(
          bytes: Uint8List.fromList(bytes),
          mimeType: message.imageMimeType ?? 'image/png');
        return ImageAttachmentService().resolve(name);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      final file = await _sourceFile();
      if (file == null) throw StateError('Image is unavailable');
      await Gal.putImage(file.path);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Photos')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save image: $error')));
    }
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      final file = await _sourceFile();
      if (file == null) throw StateError('Image is unavailable');
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share image: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (message.imageLocalPath != null)
          FutureBuilder<File?>(
            future: ImageAttachmentService().resolve(message.imageLocalPath),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.connectionState != ConnectionState.done
                  ? const SizedBox(height: 120,
                      child: Center(child: CircularProgressIndicator()))
                  : const _UnavailableImage();
              }
              return _ImagePreview(image: FileImage(snapshot.data!));
            },
          )
        else if (message.imageBase64 != null)
          _previewLegacyImage()
        else
          const SizedBox.shrink(),
        const SizedBox(height: 5),
        Wrap(spacing: 0, children: [
          IconButton(
            onPressed: () => _saveImage(context),
            icon: const Icon(Icons.download_rounded, size: 20),
            tooltip: 'Save to Photos'),
          IconButton(
            onPressed: () => _shareImage(context),
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: 'Share image'),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Generate variation'),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit image'),
        ]),
      ]);
  }

  Widget _previewLegacyImage() {
    try {
      return _ImagePreview(
        image: MemoryImage(base64Decode(message.imageBase64!)));
    } catch (_) {
      return const _UnavailableImage();
    }
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(children: [
            InteractiveViewer(
              minScale: 0.8, maxScale: 5,
              child: Center(child: Image(image: image, fit: BoxFit.contain))),
            Positioned(top: 6, right: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Close image')),
          ]),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340, maxWidth: 440),
          child: Image(image: image, fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _UnavailableImage()),
        ),
      ),
    );
  }
}

class _UnavailableImage extends StatelessWidget {
  const _UnavailableImage();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.broken_image_outlined, size: 20),
        SizedBox(width: 8),
        Text('Image unavailable'),
      ]),
    );
  }
}
