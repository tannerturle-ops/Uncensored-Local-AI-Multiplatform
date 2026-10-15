import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores image bytes in app documents, never inside the Hive chat box.
/// Relative filenames remain valid across iOS application container changes.
class ImageAttachmentService {
  static const directoryName = 'mochi_images';

  Future<Directory> _directory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, directoryName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Returns the portable relative file name to store in a message.
  Future<String> save({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('Image must not be empty');
    if (bytes.length > 25 * 1024 * 1024) {
      throw ArgumentError('Image exceeds the 25 MB attachment limit');
    }
    const extensions = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/gif': 'gif',
    };
    final ext = extensions[mimeType.toLowerCase()];
    if (ext == null) {
      throw ArgumentError('Unsupported image type: $mimeType');
    }
    final dir = await _directory();
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${bytes.length}.$ext';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return fileName;
  }

  Future<File?> resolve(String? fileName) async {
    if (fileName == null || fileName.isEmpty) return null;
    // Prevent stored filenames from escaping the app's attachment directory.
    if (p.basename(fileName) != fileName) return null;
    final directory = await _directory();
    final file = File(p.join(directory.path, fileName));
    return await file.exists() ? file : null;
  }

  Future<void> remove(String? fileName) async {
    final file = await resolve(fileName);
    if (file != null) await file.delete();
  }
}
