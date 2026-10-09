import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../services/image_attachment_service.dart';

/// Displays current on-device attachments and legacy inline image payloads.
class MessageImage extends StatelessWidget {
  const MessageImage({super.key, required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    if (message.imageLocalPath != null) {
      return FutureBuilder<File?>(
        future: ImageAttachmentService().resolve(message.imageLocalPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 130,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == null) return const _UnavailableImage();
          return _ImagePreview(image: FileImage(snapshot.data!));
        },
      );
    }
    if (message.imageBase64 != null) {
      try {
        final Uint8List bytes = base64Decode(message.imageBase64!);
        return _ImagePreview(image: MemoryImage(bytes));
      } catch (_) {
        return const _UnavailableImage();
      }
    }
    return const SizedBox.shrink();
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
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(child: Image(image: image, fit: BoxFit.contain)),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Close image',
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340, maxWidth: 440),
          child: Image(
            image: image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _UnavailableImage(),
          ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 20),
          SizedBox(width: 8),
          Text('Image unavailable'),
        ],
      ),
    );
  }
}
