import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';
import '../product_badge.dart';

/// Utility class for rendering markdown content in chat messages
class ChatMarkdownRenderer {
  /// Build message content with markdown and product badge support.
  static Widget buildMessageContent(
    String content,
    bool isUser,
    BestBuyClient? client,
  ) {
    final textColor = isUser ? AppColors.textPrimary : AppColors.textPrimary;
    final codeBackground = isUser 
        ? AppColors.surfaceVariant.withOpacity(0.5) 
        : AppColors.surfaceVariant;
    
    // For user messages, just render markdown without product badges
    if (isUser) {
      return MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: _buildMarkdownStyleSheet(textColor, codeBackground, isUser),
      );
    }
    
    // Check if content has product references
    if (ProductBadgeParser.hasProducts(content)) {
      return _buildMarkdownWithProducts(content, textColor, codeBackground, client);
    }
    
    // Regular markdown
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(textColor, codeBackground, isUser),
    );
  }
  
  /// Build markdown stylesheet for consistent styling.
  static MarkdownStyleSheet _buildMarkdownStyleSheet(
    Color textColor,
    Color codeBackground,
    bool isUser,
  ) {
    final linkColor = AppColors.primaryBlue;
    
    return MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 14, height: 1.4),
      h1: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
      h2: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
      h3: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
      h4: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
      h5: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
      h6: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
      em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      del: TextStyle(color: textColor, decoration: TextDecoration.lineThrough),
      a: TextStyle(color: linkColor, decoration: TextDecoration.underline),
      blockquote: TextStyle(color: textColor.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primaryBlue, width: 3)),
        color: codeBackground,
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      code: TextStyle(
        color: textColor,
        backgroundColor: codeBackground,
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      listBullet: TextStyle(color: textColor),
      tableHead: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      tableBody: TextStyle(color: textColor),
      tableBorder: TableBorder.all(color: AppColors.border, width: 1),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
    );
  }
  
  /// Build markdown content interspersed with product badges.
  static Widget _buildMarkdownWithProducts(
    String content,
    Color textColor,
    Color codeBackground,
    BestBuyClient? client,
  ) {
    if (client == null) {
      // Fallback to regular markdown if no client provided
      return MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: _buildMarkdownStyleSheet(textColor, codeBackground, false),
      );
    }

    final productPattern = RegExp(r'\[Product\((\d+)\)\]');
    final widgets = <Widget>[];
    int lastEnd = 0;
    
    for (final match in productPattern.allMatches(content)) {
      // Add markdown for text before this match
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          widgets.add(
            MarkdownBody(
              data: textBefore,
              selectable: true,
              styleSheet: _buildMarkdownStyleSheet(textColor, codeBackground, false),
              shrinkWrap: true,
            ),
          );
        }
      }
      
      // Add product badge
      final sku = int.parse(match.group(1)!);
      widgets.add(ProductBadge(sku: sku, client: client));
      
      lastEnd = match.end;
    }
    
    // Add remaining text as markdown
    if (lastEnd < content.length) {
      final textAfter = content.substring(lastEnd).trim();
      if (textAfter.isNotEmpty) {
        widgets.add(
          MarkdownBody(
            data: textAfter,
            selectable: true,
            styleSheet: _buildMarkdownStyleSheet(textColor, codeBackground, false),
            shrinkWrap: true,
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}

