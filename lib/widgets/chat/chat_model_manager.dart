import 'package:flutter/material.dart';
import '../../services/openrouter/openrouter_models.dart';
import '../../services/openrouter/openrouter_auth_service.dart';
import '../../services/storage/storage.dart';

/// Helper class for managing model selection and loading
class ChatModelManager {
  final OpenRouterModelsService modelsService;
  final SettingsService settings;
  
  List<OpenRouterModel> availableModels = [];
  bool isLoading = false;
  
  // Default models as fallback
  static final List<OpenRouterModel> defaultModels = [
    OpenRouterModel(id: 'openai/gpt-4o-mini', name: 'GPT-4o Mini'),
    OpenRouterModel(id: 'openai/gpt-4o', name: 'GPT-4o'),
    OpenRouterModel(id: 'anthropic/claude-3.5-sonnet', name: 'Claude 3.5 Sonnet'),
    OpenRouterModel(id: 'anthropic/claude-3-haiku', name: 'Claude 3 Haiku'),
    OpenRouterModel(id: 'google/gemini-pro-1.5', name: 'Gemini Pro 1.5'),
    OpenRouterModel(id: 'meta-llama/llama-3.1-70b-instruct', name: 'Llama 3.1 70B'),
  ];
  
  ChatModelManager({
    required this.modelsService,
    required this.settings,
  });
  
  List<OpenRouterModel> get modelsToShow => 
      availableModels.isNotEmpty ? availableModels : defaultModels;
  
  String get selectedModelId => settings.selectedModel;
  
  String getSelectedModelName() {
    final model = modelsToShow.where((m) => m.id == selectedModelId).firstOrNull;
    return model?.name ?? selectedModelId.split('/').last;
  }
  
  Future<void> loadModels() async {
    isLoading = true;
    
    try {
      availableModels = await modelsService.getModels();
      isLoading = false;
    } catch (e) {
      debugPrint('❌ Error loading models: $e');
      isLoading = false;
    }
  }
  
  void dispose() {
    modelsService.dispose();
  }
}

