import 'package:flutter/material.dart';
import '../../services/agent/chat_message.dart';
import '../../services/storage/chat_thread.dart';
import '../../theme/app_colors.dart';

/// Bottom sheet for selecting/managing chat threads
class ThreadSelectorSheet extends StatelessWidget {
  final List<ChatThread> threads;
  final String? currentThreadId;
  final void Function(ChatThread) onThreadSelected;
  final VoidCallback onNewThread;
  final void Function(String) onDeleteThread;
  final bool isAuthenticated;
  final VoidCallback onConnectOpenRouter;
  final VoidCallback onDisconnectOpenRouter;
  
  const ThreadSelectorSheet({
    super.key,
    required this.threads,
    required this.currentThreadId,
    required this.onThreadSelected,
    required this.onNewThread,
    required this.onDeleteThread,
    required this.isAuthenticated,
    required this.onConnectOpenRouter,
    required this.onDisconnectOpenRouter,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.forum_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Conversations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _NewChatButton(onTap: onNewThread),
                ],
              ),
            ),
            
            const Divider(height: 1, color: AppColors.border),
            
            // Thread list
            Expanded(
              child: threads.isEmpty
                  ? _EmptyState(onNewThread: onNewThread)
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: threads.length,
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        final isSelected = thread.id == currentThreadId;
                        
                        return _ThreadTile(
                          thread: thread,
                          isSelected: isSelected,
                          onTap: () => onThreadSelected(thread),
                          onDelete: () => _confirmDelete(context, thread),
                        );
                      },
                    ),
            ),
            
            // OpenRouter connection status
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _OpenRouterStatusTile(
                isAuthenticated: isAuthenticated,
                onConnect: onConnectOpenRouter,
                onDisconnect: onDisconnectOpenRouter,
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _confirmDelete(BuildContext context, ChatThread thread) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete conversation?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently delete "${thread.title}" and all its messages.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteThread(thread.id);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// New chat button with animation
class _NewChatButton extends StatefulWidget {
  final VoidCallback onTap;

  const _NewChatButton({required this.onTap});

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _isPressed
              ? AppColors.primaryBlue.withOpacity(0.8)
              : AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no threads exist
class _EmptyState extends StatelessWidget {
  final VoidCallback onNewThread;

  const _EmptyState({required this.onNewThread});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new conversation to get going',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onNewThread,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Start a conversation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thread tile with delete button
class _ThreadTile extends StatefulWidget {
  final ChatThread thread;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ThreadTile({
    required this.thread,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ThreadTile> createState() => _ThreadTileState();
}

class _ThreadTileState extends State<_ThreadTile> {
  bool _isPressed = false;

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  int get _messageCount => widget.thread.messages
      .where((m) => m.role == MessageRole.user)
      .length;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isPressed
              ? AppColors.surfaceVariant
              : widget.isSelected
                  ? AppColors.primaryBlue.withOpacity(0.1)
                  : AppColors.userMessageBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected
                ? AppColors.primaryBlue.withOpacity(0.5)
                : AppColors.border.withOpacity(0.3),
            width: widget.isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.primaryBlue
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: widget.isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.thread.title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(widget.thread.lastUpdatedAt),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_messageCount messages',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Actions
            if (widget.isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              )
            else
              GestureDetector(
                onTap: widget.onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// OpenRouter connection status tile
class _OpenRouterStatusTile extends StatelessWidget {
  final bool isAuthenticated;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _OpenRouterStatusTile({
    required this.isAuthenticated,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAuthenticated ? onDisconnect : onConnect,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAuthenticated 
              ? AppColors.success.withOpacity(0.1) 
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAuthenticated 
                ? AppColors.success.withOpacity(0.3) 
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAuthenticated 
                    ? AppColors.success.withOpacity(0.2) 
                    : AppColors.border.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAuthenticated 
                    ? Icons.cloud_done_rounded 
                    : Icons.cloud_off_rounded,
                size: 20,
                color: isAuthenticated 
                    ? AppColors.success 
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAuthenticated ? 'Connected to OpenRouter' : 'Not Connected',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAuthenticated 
                        ? 'Tap to disconnect' 
                        : 'Tap to connect for AI features',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
