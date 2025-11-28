import 'package:flutter/material.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';

/// Widget for the chat input area with attachment preview and animations
class ChatInputArea extends StatefulWidget {
  final TextEditingController inputController;
  final bool isProcessing;
  final BestBuyProduct? attachedProduct;
  final VoidCallback onClearAttachment;
  final VoidCallback onSendMessage;
  
  const ChatInputArea({
    super.key,
    required this.inputController,
    required this.isProcessing,
    this.attachedProduct,
    required this.onClearAttachment,
    required this.onSendMessage,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    
    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _sendButtonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  void _onSendTapDown(TapDownDetails details) {
    _sendButtonController.forward();
  }

  void _onSendTapUp(TapUpDetails details) {
    _sendButtonController.reverse();
    if (!widget.isProcessing) {
      widget.onSendMessage();
    }
  }

  void _onSendTapCancel() {
    _sendButtonController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment preview (if product attached)
            if (widget.attachedProduct != null) _buildAttachmentPreview(),
            
            // Input row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: _isFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: TextField(
                        controller: widget.inputController,
                        focusNode: _focusNode,
                        enabled: !widget.isProcessing,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: widget.attachedProduct != null 
                              ? 'Ask about this product...'
                              : widget.isProcessing 
                                  ? 'Thinking...' 
                                  : 'Message...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.border.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.primaryBlue.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => widget.onSendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTapDown: _onSendTapDown,
                    onTapUp: _onSendTapUp,
                    onTapCancel: _onSendTapCancel,
                    child: ScaleTransition(
                      scale: _sendButtonScale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: widget.isProcessing 
                              ? AppColors.surfaceVariant 
                              : AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          boxShadow: widget.isProcessing
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: widget.isProcessing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build the attachment preview for the product above the input field
  Widget _buildAttachmentPreview() {
    final product = widget.attachedProduct!;
    final imageUrl = product.thumbnailImage ?? 
                     product.mediumImage ?? 
                     product.image ?? 
                     product.largeImage;
    
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.userMessageBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // Product thumbnail
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2_outlined,
                            size: 24,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Attached',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Remove button
              GestureDetector(
                onTap: widget.onClearAttachment,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
