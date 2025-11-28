import 'package:flutter/services.dart';
import 'tool_registry.dart';

/// Loads and processes prompt templates from assets.
class PromptLoader {
  static const String _systemPromptPath = 'lib/assets/prompts/system_prompt.md';
  
  String? _cachedPrompt;
  
  /// Load the system prompt template and fill in dynamic values.
  Future<String> loadSystemPrompt() async {
    // Load from assets if not cached
    _cachedPrompt ??= await rootBundle.loadString(_systemPromptPath);
    
    // Process template variables
    return _processTemplate(_cachedPrompt!);
  }
  
  /// Process template variables in the prompt.
  String _processTemplate(String template) {
    var result = template;
    
    // Replace {{TOOLS_LIST}} with actual tools
    result = result.replaceAll('{{TOOLS_LIST}}', _buildToolsList());
    
    return result;
  }
  
  /// Build a formatted list of available tools.
  String _buildToolsList() {
    final tools = ToolRegistry.instance.all;
    
    if (tools.isEmpty) {
      return '- No tools currently available';
    }
    
    final buffer = StringBuffer();
    for (final tool in tools) {
      buffer.writeln('- **${tool.name}**: ${tool.description}');
    }
    
    return buffer.toString().trimRight();
  }
  
  /// Clear the cached prompt (useful for hot reload).
  void clearCache() {
    _cachedPrompt = null;
  }
}

