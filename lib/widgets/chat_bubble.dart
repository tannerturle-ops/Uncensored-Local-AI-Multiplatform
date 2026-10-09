import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../models/message_model.dart';
import '../services/llm_service.dart';
import 'message_image.dart';

/// A single, consistent message layout for local and cloud responses.
/// Thinking is displayed by the chat list, outside any message bubble.
class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool showSpeed;

  const ChatBubble({
    super.key,
    required this.message,
    this.showSpeed = false,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;
    final horizontalPad = isCompact ? 16.0 : 24.0;
    final maxBubbleWidth = isCompact ? width * 0.78 : 740.0;
    final bubbleColor = isUser
        ? (context.isDark ? const Color(0xFF48253A) : const Color(0xFFFBE3EF))
        : (context.isDark ? const Color(0xFF242427) : const Color(0xFFFFF1F7));

    if (message.isSystem) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 17,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: context.isDark
                            ? Colors.white.withOpacity(0.035)
                            : AppColors.accent.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.imageLocalPath != null ||
                            message.imageBase64 != null) ...[
                          MessageImage(message: message),
                          if (message.content.isNotEmpty)
                            const SizedBox(height: 10),
                        ],
                        if (message.content.isNotEmpty)
                          isUser
                        ? SelectableText(
                            message.content,
                            style: TextStyle(
                              color: context.text,
                              fontSize: 15,
                              height: 1.55,
                            ),
                          )
                        : MarkdownBody(
                            data: message.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                  fontSize: 15,
                                  height: 1.65,
                                  color: context.text),
                              h1: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: context.text),
                              h2: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: context.text),
                              h3: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.text),
                              code: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: context.text,
                                backgroundColor: context.isDark
                                    ? Colors.white.withOpacity(0.07)
                                    : Colors.black.withOpacity(0.05),
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: context.isDark
                                    ? const Color(0xFF17171A)
                                    : const Color(0xFFF7E7EF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              codeblockPadding: const EdgeInsets.all(12),
                              blockquoteDecoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.08),
                                border: const Border(
                                  left: BorderSide(
                                      color: AppColors.accent, width: 3),
                                ),
                              ),
                              blockquotePadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                              listBullet: TextStyle(color: context.text),
                              tableHead: TextStyle(color: context.text),
                              tableBody: TextStyle(color: context.text),
                              tableBorder:
                                  TableBorder.all(color: context.border),
                              tableCellsPadding: const EdgeInsets.all(8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (message.content.isNotEmpty || message.imageLocalPath != null ||
                      message.imageBase64 != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 3, top: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _copy(context),
                            tooltip: 'Copy message',
                            icon: Icon(Icons.copy_rounded,
                                size: 16, color: context.textD),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                                minWidth: 34, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          if (!isUser && showSpeed)
                            Obx(() {
                              final llm = Get.find<LlmService>();
                              final speed = llm.isGenerating.value
                                  ? llm.tokensPerSecond.value
                                  : llm.lastGenerationSpeed.value;
                              if (speed <= 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '${speed.toStringAsFixed(1)} t/s',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textD,
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
