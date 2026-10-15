import 'package:hive/hive.dart';

part 'message_model.g.dart';

@HiveType(typeId: 1)
enum MessageRole {
  @HiveField(0)
  user,
  @HiveField(1)
  assistant,
  @HiveField(2)
  system,
}

@HiveType(typeId: 2)
class MessageModel extends HiveObject {
  @HiveField(0)
  final MessageRole role;

  @HiveField(1)
  String content;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  String? imageBase64;

  @HiveField(4)
  String? imageMimeType;

  // Stored as a file instead of inlining large image payloads into Hive.
  @HiveField(5)
  String? imageLocalPath;

  // Stable image identity and the image this was edited from, if any.
  @HiveField(6)
  String? imageId;

  @HiveField(7)
  String? sourceImageId;

  @HiveField(8)
  String? imageProvider;

  @HiveField(9)
  String? imagePrompt;

  MessageModel({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.imageBase64,
    this.imageMimeType,
    this.imageLocalPath,
    this.imageId,
    this.sourceImageId,
    this.imageProvider,
    this.imagePrompt,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;

  Map<String, String> toLlamaMessage() {
    return {
      'role': role.name,
      'content': content,
    };
  }
}
