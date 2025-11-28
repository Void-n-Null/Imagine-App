import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Animated thinking indicator with pulsing dots
class ChatThinkingIndicator extends StatefulWidget {
  final String? status;
  
  const ChatThinkingIndicator({
    super.key, 
    this.status,
  });

  @override
  State<ChatThinkingIndicator> createState() => _ChatThinkingIndicatorState();
}

class _ChatThinkingIndicatorState extends State<ChatThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Stagger the animation for each dot
                  final delay = index * 0.2;
                  final value = (_controller.value + delay) % 1.0;
                  
                  // Create a smooth pulse effect
                  final scale = 0.5 + (0.5 * _pulse(value));
                  final opacity = 0.4 + (0.6 * _pulse(value));
                  
                  return Container(
                    margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.thinkingDot.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          
          // Status Text
          if (widget.status != null && widget.status!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              widget.status!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Creates a smooth pulse curve using sine wave
  double _pulse(double t) {
    return (1 + math.sin(t * 2 * math.pi)) / 2;
  }
}
