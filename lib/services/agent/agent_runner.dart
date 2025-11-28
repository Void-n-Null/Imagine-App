import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../openrouter/openrouter_auth_service.dart';
import 'chat_message.dart';
import 'tool.dart';
import 'tool_registry.dart';

/// Configuration for the agent
class AgentConfig {
  final String model;
  final String? systemPrompt;
  final int maxIterations;
  
  const AgentConfig({
    this.model = 'openai/gpt-4o-mini',
    this.systemPrompt,
    this.maxIterations = 10,
  });
}

/// Runs the agentic loop: LLM -> tool calls -> execute -> repeat until done
class AgentRunner {
  final OpenRouterAuthService _authService;
  final ToolRegistry _toolRegistry;
  final http.Client _httpClient;
  final AgentConfig config;
  
  AgentRunner({
    OpenRouterAuthService? authService,
    ToolRegistry? toolRegistry,
    http.Client? httpClient,
    this.config = const AgentConfig(),
  }) : _authService = authService ?? OpenRouterAuthService(),
       _toolRegistry = toolRegistry ?? ToolRegistry.instance,
       _httpClient = httpClient ?? http.Client();
  
  /// Run the agent with a user message.
  /// 
  /// Returns a stream of [ChatMessage] objects representing the conversation.
  /// The stream includes:
  /// - Assistant messages (possibly with tool calls)
  /// - Tool result messages
  /// - Final assistant response
  Stream<ChatMessage> run(List<ChatMessage> history, String userMessage) async* {
    final apiKey = await _authService.getApiKey();
    if (apiKey == null) {
      yield ChatMessage.assistant('Please connect to OpenRouter first.');
      return;
    }
    
    // Build message history for API
    final messages = <Map<String, dynamic>>[];
    
    // Add system prompt if configured
    if (config.systemPrompt != null) {
      messages.add({'role': 'system', 'content': config.systemPrompt});
    }
    
    // Add conversation history
    for (final msg in history) {
      messages.add(msg.toApiMessage());
    }
    
    // Add the new user message
    messages.add({'role': 'user', 'content': userMessage});
    
    // Agentic loop
    int iterations = 0;
    while (iterations < config.maxIterations) {
      iterations++;
      
      debugPrint('🤖 Agent iteration $iterations');
      
      // Call the LLM
      final response = await _callLLM(apiKey, messages);
      
      if (response == null) {
        yield ChatMessage.assistant('Sorry, I encountered an error communicating with the AI.');
        return;
      }
      
      final choice = response['choices']?[0];
      final message = choice?['message'];
      
      if (message == null) {
        yield ChatMessage.assistant('Sorry, I received an unexpected response.');
        return;
      }
      
      final content = message['content'] as String? ?? '';
      final toolCallsJson = message['tool_calls'] as List<dynamic>?;
      
      // Parse tool calls if present
      List<ToolCall>? toolCalls;
      if (toolCallsJson != null && toolCallsJson.isNotEmpty) {
        toolCalls = toolCallsJson
            .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
            .toList();
      }
      
      // Yield the assistant message
      final assistantMsg = ChatMessage.assistant(content, toolCalls: toolCalls);
      yield assistantMsg;
      
      // Add to messages for next iteration
      messages.add(_buildAssistantMessage(content, toolCallsJson));
      
      // If no tool calls, we're done
      if (toolCalls == null || toolCalls.isEmpty) {
        debugPrint('✅ Agent completed (no tool calls)');
        return;
      }
      
      // Execute tool calls
      for (final toolCall in toolCalls) {
        debugPrint('🔧 Executing tool: ${toolCall.name}');
        
        final tool = _toolRegistry.get(toolCall.name);
        String resultContent;
        
        if (tool == null) {
          resultContent = 'Error: Tool "${toolCall.name}" not found';
        } else {
          try {
            resultContent = await tool.execute(toolCall.arguments);
          } catch (e) {
            resultContent = 'Error executing tool: $e';
          }
        }
        
        // Yield tool result message
        final toolResultMsg = ChatMessage.toolResult(
          toolCallId: toolCall.id,
          toolName: toolCall.name,
          content: resultContent,
        );
        yield toolResultMsg;
        
        // Add to messages for next iteration
        messages.add({
          'role': 'tool',
          'tool_call_id': toolCall.id,
          'content': resultContent,
        });
      }
    }
    
    debugPrint('⚠️ Agent hit max iterations ($iterations)');
    yield ChatMessage.assistant('I reached the maximum number of steps. Please try again with a simpler request.');
  }
  
  Future<Map<String, dynamic>?> _callLLM(
    String apiKey,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final tools = _toolRegistry.toolSchemas;
      
      final body = <String, dynamic>{
        'model': config.model,
        'messages': messages,
      };
      
      // Only include tools if we have any registered
      if (tools.isNotEmpty) {
        body['tools'] = tools;
      }
      
      debugPrint('📤 Sending ${messages.length} messages, ${tools.length} tools');
      
      final response = await _httpClient.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/imagineapp',
          'X-Title': 'ImagineApp',
        },
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Request error: $e');
      return null;
    }
  }
  
  Map<String, dynamic> _buildAssistantMessage(String content, List<dynamic>? toolCalls) {
    final msg = <String, dynamic>{
      'role': 'assistant',
      'content': content,
    };
    
    if (toolCalls != null && toolCalls.isNotEmpty) {
      msg['tool_calls'] = toolCalls;
    }
    
    return msg;
  }
  
  void dispose() {
    _httpClient.close();
  }
}

