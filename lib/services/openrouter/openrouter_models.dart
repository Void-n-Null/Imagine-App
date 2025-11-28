import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents an OpenRouter model
class OpenRouterModel {
  final String id;
  final String name;
  final String? description;
  final double? promptPricing; // per 1M tokens
  final double? completionPricing; // per 1M tokens
  final int? contextLength;
  
  OpenRouterModel({
    required this.id,
    required this.name,
    this.description,
    this.promptPricing,
    this.completionPricing,
    this.contextLength,
  });
  
  factory OpenRouterModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    
    return OpenRouterModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      description: json['description'] as String?,
      promptPricing: _parsePrice(pricing?['prompt']),
      completionPricing: _parsePrice(pricing?['completion']),
      contextLength: json['context_length'] as int?,
    );
  }
  
  static double? _parsePrice(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  /// Get a display-friendly price string
  String get priceDisplay {
    if (promptPricing == null) return 'Free';
    if (promptPricing == 0) return 'Free';
    
    // Price is per token, convert to per 1M tokens for display
    final perMillion = promptPricing! * 1000000;
    if (perMillion < 0.01) return '<\$0.01/1M';
    return '\$${perMillion.toStringAsFixed(2)}/1M';
  }
  
  /// Get provider name from model ID
  String get provider {
    final parts = id.split('/');
    return parts.isNotEmpty ? parts[0] : 'unknown';
  }
}

/// Service for fetching OpenRouter models
class OpenRouterModelsService {
  final http.Client _httpClient;
  List<OpenRouterModel>? _cachedModels;
  DateTime? _cacheTime;
  
  static const Duration _cacheDuration = Duration(minutes: 30);
  
  OpenRouterModelsService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();
  
  /// Fetch all available models from OpenRouter
  Future<List<OpenRouterModel>> getModels({bool forceRefresh = false}) async {
    // Return cached if valid
    if (!forceRefresh && _cachedModels != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        debugPrint('📋 Returning ${_cachedModels!.length} cached models');
        return _cachedModels!;
      }
    }
    
    try {
      debugPrint('🔄 Fetching models from OpenRouter...');
      final response = await _httpClient.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      debugPrint('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final modelsJson = data['data'] as List<dynamic>? ?? [];
        
        debugPrint('📋 Parsed ${modelsJson.length} models from response');
        
        _cachedModels = modelsJson
            .map((m) => OpenRouterModel.fromJson(m as Map<String, dynamic>))
            .toList();
        
        // Sort by name
        _cachedModels!.sort((a, b) => a.name.compareTo(b.name));
        
        _cacheTime = DateTime.now();
        debugPrint('✅ Loaded ${_cachedModels!.length} models from OpenRouter');
        
        return _cachedModels!;
      } else {
        debugPrint('❌ Failed to fetch models: ${response.statusCode} - ${response.body}');
        return _getDefaultModels();
      }
    } catch (e, stack) {
      debugPrint('❌ Error fetching models: $e');
      debugPrint('Stack: $stack');
      return _getDefaultModels();
    }
  }
  
  /// Get popular/recommended models for quick selection
  List<OpenRouterModel> getPopularModels(List<OpenRouterModel> allModels) {
    const popularIds = [
      'openai/gpt-4o',
      'openai/gpt-4o-mini',
      'anthropic/claude-3.5-sonnet',
      'anthropic/claude-3-haiku',
      'google/gemini-pro-1.5',
      'meta-llama/llama-3.1-70b-instruct',
      'mistralai/mistral-large',
    ];
    
    return allModels.where((m) => popularIds.contains(m.id)).toList();
  }
  
  /// Default models if API fails
  List<OpenRouterModel> _getDefaultModels() {
    return [
      OpenRouterModel(id: 'openai/gpt-4o-mini', name: 'GPT-4o Mini'),
      OpenRouterModel(id: 'openai/gpt-4o', name: 'GPT-4o'),
      OpenRouterModel(id: 'anthropic/claude-3.5-sonnet', name: 'Claude 3.5 Sonnet'),
      OpenRouterModel(id: 'anthropic/claude-3-haiku', name: 'Claude 3 Haiku'),
      OpenRouterModel(id: 'google/gemini-pro-1.5', name: 'Gemini Pro 1.5'),
    ];
  }
  
  void dispose() {
    _httpClient.close();
  }
}

