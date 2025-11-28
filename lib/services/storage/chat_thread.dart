import 'package:uuid/uuid.dart';
import '../agent/chat_message.dart';
import '../agent/tool.dart';

/// Represents a persistent chat thread/conversation.
class ChatThread {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  List<ChatMessage> messages;
  
  /// Optional product SKU that was used to start this thread
  int? initialProductSku;
  
  ChatThread({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    List<ChatMessage>? messages,
    this.initialProductSku,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? 'New Chat',
        createdAt = createdAt ?? DateTime.now(),
        lastUpdatedAt = lastUpdatedAt ?? DateTime.now(),
        messages = messages ?? [];
  
  /// Check if thread is empty (no user messages)
  bool get isEmpty => messages.where((m) => m.role == MessageRole.user).isEmpty;
  
  /// Get the last user message for preview
  String? get lastUserMessage {
    final userMessages = messages.where((m) => m.role == MessageRole.user).toList();
    return userMessages.isEmpty ? null : userMessages.last.content;
  }
  
  /// Get a preview of the thread for the UI
  String get preview {
    if (isEmpty) return 'No messages yet';
    // Try to get last assistant response, else last user message
    final assistantMessages = messages.where((m) => 
      m.role == MessageRole.assistant && m.content.isNotEmpty).toList();
    if (assistantMessages.isNotEmpty) {
      return assistantMessages.last.content;
    }
    return lastUserMessage ?? 'No messages yet';
  }
  
  /// Update the title based on first user message if still default
  void updateTitleFromFirstMessage() {
    if (title == 'New Chat' && messages.isNotEmpty) {
      final firstUserMsg = messages.where((m) => m.role == MessageRole.user).firstOrNull;
      if (firstUserMsg != null) {
        // Truncate to reasonable length
        final content = firstUserMsg.content;
        title = content.length > 40 ? '${content.substring(0, 40)}...' : content;
      }
    }
  }
  
  /// Add a message to the thread
  void addMessage(ChatMessage message) {
    messages.add(message);
    lastUpdatedAt = DateTime.now();
    updateTitleFromFirstMessage();
  }
  
  /// Update a message in place (by id)
  void updateMessage(ChatMessage updatedMessage) {
    final index = messages.indexWhere((m) => m.id == updatedMessage.id);
    if (index != -1) {
      messages[index] = updatedMessage;
      lastUpdatedAt = DateTime.now();
    }
  }
  
  /// Mark a tool call as completed on the relevant assistant message
  void markToolCallCompleted(String toolCallId) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == MessageRole.assistant && 
          msg.toolCalls != null &&
          msg.toolCalls!.any((tc) => tc.id == toolCallId)) {
        messages[i] = msg.withToolCallCompleted(toolCallId);
        lastUpdatedAt = DateTime.now();
        break;
      }
    }
  }
  
  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'initialProductSku': initialProductSku,
      'messages': messages.map((m) => _messageToJson(m)).toList(),
    };
  }
  
  /// Create from JSON
  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New Chat',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
      initialProductSku: json['initialProductSku'] as int?,
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => _messageFromJson(m as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  static Map<String, dynamic> _messageToJson(ChatMessage message) {
    return {
      'id': message.id,
      'role': message.role.name,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'toolCallId': message.toolCallId,
      'toolName': message.toolName,
      'attachedProductSku': message.attachedProductSku,
      'toolCalls': message.toolCalls?.map((tc) => {
        'id': tc.id,
        'name': tc.name,
        'arguments': tc.arguments,
      }).toList(),
    };
  }
  
  static ChatMessage _messageFromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String;
    final role = MessageRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => MessageRole.user,
    );
    
    List<ToolCall>? toolCalls;
    if (json['toolCalls'] != null) {
      toolCalls = (json['toolCalls'] as List<dynamic>).map((tc) {
        final tcMap = tc as Map<String, dynamic>;
        return ToolCall(
          id: tcMap['id'] as String,
          name: tcMap['name'] as String,
          arguments: Map<String, dynamic>.from(tcMap['arguments'] as Map),
        );
      }).toList();
    }
    
    return ChatMessage(
      id: json['id'] as String,
      role: role,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolCallId: json['toolCallId'] as String?,
      toolName: json['toolName'] as String?,
      attachedProductSku: json['attachedProductSku'] as int?,
      toolCalls: toolCalls,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatThread && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

