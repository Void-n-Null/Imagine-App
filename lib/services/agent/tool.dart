import 'dart:convert';

/// Base class for all agent tools.
/// 
/// Tools must implement [name], [description], [parameters], and [execute].
/// The [toOpenAISchema] method generates the OpenAI-compatible function schema.
abstract class Tool {
  /// Unique identifier for this tool (used in function calls)
  String get name;
  
  /// Human-readable name shown in the UI while tool is executing (e.g., "Searching Products...")
  /// Defaults to a formatted version of [name] if not overridden.
  String get displayName => '${formatToolName(name)}...';
  
  /// Formats a snake_case tool name into Title Case
  static String formatToolName(String name) {
    return name
        .split('_')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}' 
            : '')
        .join(' ');
  }
  
  /// Human-readable description of what this tool does
  String get description;
  
  /// JSON Schema for the tool's parameters
  /// Example:
  /// ```dart
  /// {
  ///   'type': 'object',
  ///   'properties': {
  ///     'query': {'type': 'string', 'description': 'Search query'}
  ///   },
  ///   'required': ['query']
  /// }
  /// ```
  Map<String, dynamic> get parameters;
  
  /// Execute the tool with the given arguments.
  /// Returns a string result that will be sent back to the agent.
  Future<String> execute(Map<String, dynamic> args);
  
  /// Generate OpenAI-compatible function schema for this tool.
  Map<String, dynamic> toOpenAISchema() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

/// Represents a tool call from the LLM response
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  
  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
  
  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final function = json['function'] as Map<String, dynamic>;
    final argsString = function['arguments'] as String? ?? '{}';
    
    Map<String, dynamic> args;
    try {
      args = jsonDecode(argsString) as Map<String, dynamic>;
    } catch (_) {
      args = {};
    }
    
    return ToolCall(
      id: json['id'] as String,
      name: function['name'] as String,
      arguments: args,
    );
  }
}

/// Result of executing a tool
class ToolResult {
  final String toolCallId;
  final String content;
  final bool isError;
  
  ToolResult({
    required this.toolCallId,
    required this.content,
    this.isError = false,
  });
  
  Map<String, dynamic> toMessage() => {
    'role': 'tool',
    'tool_call_id': toolCallId,
    'content': content,
  };
}

