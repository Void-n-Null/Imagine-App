import 'tool.dart';

/// Central registry for all available tools.
/// 
/// Tools register themselves via [register] and can be looked up by name.
/// The registry provides the combined schema for all tools to send to the LLM.
class ToolRegistry {
  ToolRegistry._();
  
  static final ToolRegistry instance = ToolRegistry._();
  
  final Map<String, Tool> _tools = {};
  
  /// Register a tool. Throws if a tool with the same name already exists.
  void register(Tool tool) {
    if (_tools.containsKey(tool.name)) {
      throw StateError('Tool "${tool.name}" is already registered');
    }
    _tools[tool.name] = tool;
  }
  
  /// Unregister a tool by name.
  void unregister(String name) {
    _tools.remove(name);
  }
  
  /// Get a tool by name, or null if not found.
  Tool? get(String name) => _tools[name];
  
  /// Get all registered tools.
  List<Tool> get all => _tools.values.toList();
  
  /// Get the names of all registered tools.
  List<String> get names => _tools.keys.toList();
  
  /// Check if a tool is registered.
  bool has(String name) => _tools.containsKey(name);
  
  /// Get OpenAI-compatible schema for all registered tools.
  List<Map<String, dynamic>> get toolSchemas =>
      _tools.values.map((t) => t.toOpenAISchema()).toList();
  
  /// Get the display name for a tool by its name.
  /// Returns a formatted fallback if tool is not found.
  String getDisplayName(String toolName) {
    final tool = _tools[toolName];
    if (tool != null) {
      return tool.displayName;
    }
    // Fallback: format the tool name
    return '${Tool.formatToolName(toolName)}...';
  }
  
  /// Clear all registered tools (useful for testing).
  void clear() => _tools.clear();
}

