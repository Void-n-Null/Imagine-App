import 'tool.dart';

/// Represents a message in the chat conversation.
enum MessageRole { user, assistant, tool, system }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  
  /// For assistant messages that contain tool calls
  final List<ToolCall>? toolCalls;
  
  /// For tool result messages
  final String? toolCallId;
  final String? toolName;
  
  /// Whether the assistant is still generating this message
  final bool isStreaming;
  
  /// For user messages with an attached product (for visual rendering)
  final int? attachedProductSku;
  
  /// Set of tool call IDs that have completed (received results)
  final Set<String> completedToolCallIds;
  
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolCalls,
    this.toolCallId,
    this.toolName,
    this.isStreaming = false,
    this.attachedProductSku,
    Set<String>? completedToolCallIds,
  }) : timestamp = timestamp ?? DateTime.now(),
       completedToolCallIds = completedToolCallIds ?? {};
  
  /// Check if a specific tool call has completed
  bool isToolCallCompleted(String toolCallId) => completedToolCallIds.contains(toolCallId);
  
  /// Check if all tool calls have completed
  bool get allToolCallsCompleted {
    if (toolCalls == null || toolCalls!.isEmpty) return true;
    return toolCalls!.every((tc) => completedToolCallIds.contains(tc.id));
  }
  
  /// Create a user message
  /// Optionally attach a product SKU for visual rendering in chat
  factory ChatMessage.user(String content, {int? attachedProductSku}) => ChatMessage(
    id: _generateId(),
    role: MessageRole.user,
    content: content,
    attachedProductSku: attachedProductSku,
  );
  
  /// Create an assistant message
  factory ChatMessage.assistant(String content, {List<ToolCall>? toolCalls, bool isStreaming = false}) => ChatMessage(
    id: _generateId(),
    role: MessageRole.assistant,
    content: content,
    toolCalls: toolCalls,
    isStreaming: isStreaming,
  );
  
  /// Create a tool result message
  factory ChatMessage.toolResult({
    required String toolCallId,
    required String toolName,
    required String content,
  }) => ChatMessage(
    id: _generateId(),
    role: MessageRole.tool,
    content: content,
    toolCallId: toolCallId,
    toolName: toolName,
  );
  
  /// Create a system message
  factory ChatMessage.system(String content) => ChatMessage(
    id: _generateId(),
    role: MessageRole.system,
    content: content,
  );
  
  /// Convert to OpenAI message format for API calls
  Map<String, dynamic> toApiMessage() {
    switch (role) {
      case MessageRole.user:
        return {'role': 'user', 'content': content};
      case MessageRole.assistant:
        final msg = <String, dynamic>{'role': 'assistant', 'content': content};
        if (toolCalls != null && toolCalls!.isNotEmpty) {
          msg['tool_calls'] = toolCalls!.map((tc) => {
            'id': tc.id,
            'type': 'function',
            'function': {
              'name': tc.name,
              'arguments': tc.arguments.toString(),
            },
          }).toList();
        }
        return msg;
      case MessageRole.tool:
        return {
          'role': 'tool',
          'tool_call_id': toolCallId,
          'content': content,
        };
      case MessageRole.system:
        return {'role': 'system', 'content': content};
    }
  }
  
  /// Copy with updated fields
  ChatMessage copyWith({
    String? content,
    List<ToolCall>? toolCalls,
    bool? isStreaming,
    int? attachedProductSku,
    Set<String>? completedToolCallIds,
  }) => ChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    timestamp: timestamp,
    toolCalls: toolCalls ?? this.toolCalls,
    toolCallId: toolCallId,
    toolName: toolName,
    isStreaming: isStreaming ?? this.isStreaming,
    attachedProductSku: attachedProductSku ?? this.attachedProductSku,
    completedToolCallIds: completedToolCallIds ?? this.completedToolCallIds,
  );
  
  /// Create a copy with a tool call marked as completed
  ChatMessage withToolCallCompleted(String toolCallId) {
    final newCompletedIds = Set<String>.from(completedToolCallIds)..add(toolCallId);
    return copyWith(completedToolCallIds: newCompletedIds);
  }
  
  static int _idCounter = 0;
  static String _generateId() => 'msg_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
}

