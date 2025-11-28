import 'package:flutter/material.dart';
import '../../services/agent/chat_message.dart';
import '../../services/agent/tool_registry.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';
import 'chat_markdown_renderer.dart';

/// Widget for displaying a chat message with modern styling
/// - AI messages: No card, direct markdown rendering
/// - User messages: Dark card, left-aligned
/// - No icons for either
class ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final BestBuyClient? client;
  
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.client,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final isTool = widget.message.role == MessageRole.tool;
    final isAssistant = widget.message.role == MessageRole.assistant;
    final hasAttachedProduct = isUser && widget.message.attachedProductSku != null;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: isUser
                ? _buildUserMessage(hasAttachedProduct)
                : _buildAssistantMessage(isTool, isAssistant),
          ),
        ),
      ),
    );
  }

  /// Build user message with dark card styling
  Widget _buildUserMessage(bool hasAttachedProduct) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.userMessageBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show attached product badge for user messages
          if (hasAttachedProduct) ...[
            _buildUserProductBadge(widget.message.attachedProductSku!),
            const SizedBox(height: 10),
          ],
          if (widget.message.content.isNotEmpty)
            ChatMarkdownRenderer.buildMessageContent(
              widget.message.content,
              true,
              widget.client,
            ),
        ],
      ),
    );
  }

  /// Build assistant/tool message without card - direct markdown
  Widget _buildAssistantMessage(bool isTool, bool isAssistant) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.95,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTool) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentYellow.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.build_rounded,
                    size: 14,
                    color: AppColors.accentYellow,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.message.toolName ?? 'Tool',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentYellow,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          /* Tool calls are now displayed in the thinking indicator
          if (isAssistant && widget.message.toolCalls != null && widget.message.toolCalls!.isNotEmpty) ...[
            // Only show tool calls that haven't completed yet
            for (final tc in widget.message.toolCalls!.where(
              (tc) => !widget.message.isToolCallCompleted(tc.id)
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ToolRegistry.instance.getDisplayName(tc.name),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.message.content.isNotEmpty && 
                !widget.message.allToolCallsCompleted) const SizedBox(height: 8),
          ],
          */
          if (widget.message.content.isNotEmpty)
            ChatMarkdownRenderer.buildMessageContent(
              widget.message.content,
              false,
              widget.client,
            ),
        ],
      ),
    );
  }
  
  /// Build a compact product badge for user messages with attached products.
  Widget _buildUserProductBadge(int sku) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'Product SKU: $sku',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
