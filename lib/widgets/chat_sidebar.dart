import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../controllers/chat_controller.dart';

class ChatSidebar extends StatefulWidget {
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectChat;
  final ValueChanged<String> onDeleteChat;
  final bool showNewChatButton;

  const ChatSidebar({
    super.key,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onDeleteChat,
    this.showNewChatButton = true,
  });

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ChatController>();

    return Column(
      children: [
        // New chat button
        if (widget.showNewChatButton)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onNewChat,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'New Chat',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: context.text,
                  elevation: 0,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: context.border, width: 1),
                  ),
                ),
              ),
            ),
          ),

        // Search saved conversations by title or message content.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              hintText: 'Search conversations',
              isDense: true,
              suffixIcon: _search.text.isEmpty ? null : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => setState(() => _search.clear()),
              ),
            ),
          ),
        ),
        // Chat list
        Expanded(
          child: Obx(() {
            final query = _search.text.trim().toLowerCase();
            final chats = ctrl.chats.where((chat) => query.isEmpty ||
              chat.title.toLowerCase().contains(query) ||
              chat.messages.any((m) => m.content.toLowerCase().contains(query)))
              .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            if (chats.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 36, color: context.textD),
                    const SizedBox(height: 12),
                    Text(
                      query.isEmpty ? 'No chats yet' : 'No matching conversations',
                      style: TextStyle(fontSize: 13, color: context.textD),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final isActive = chat.id == ctrl.activeChatId.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isActive ? context.bgHover : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => widget.onSelectChat(chat.id),
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: context.bgHover,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 15,
                              color: isActive ? context.text : context.textD,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                chat.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                  color: isActive ? context.text : context.textM,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _renameChat(context, chat.id, chat.title),
                              icon: Icon(Icons.edit_outlined, size: 15, color: context.textD),
                              tooltip: 'Rename chat',
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                            // Delete button with confirmation
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: IconButton(
                                onPressed: () => _confirmDelete(context, chat.id, chat.title),
                                icon: Icon(Icons.close_rounded, size: 14, color: context.textD),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.borderFaint)),
          ),
          child: Row(
            children: [
              Icon(Icons.save_outlined, size: 14, color: context.textD),
              const SizedBox(width: 8),
              Text(
                'Chats saved locally',
                style: TextStyle(fontSize: 11, color: context.textD),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _renameChat(BuildContext context, String chatId, String currentTitle) async {
    final field = TextEditingController(text: currentTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Chat name'),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, field.text), child: const Text('Save')),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      Get.find<ChatController>().renameChat(chatId, title);
    }
    field.dispose();
  }

  void _confirmDelete(BuildContext context, String chatId, String chatTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Chat',
          style: TextStyle(
            color: context.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Delete "$chatTitle"?\nThis action cannot be undone.',
          style: TextStyle(color: context.textM, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textD)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteChat(chatId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
