import '../../services/agent/agent.dart';
import '../../services/agent/prompt_loader.dart';

/// Helper class for managing agent initialization and configuration
class ChatAgentManager {
  final PromptLoader promptLoader;
  AgentRunner? agentRunner;
  String? systemPrompt;
  
  ChatAgentManager({
    required this.promptLoader,
  });
  
  Future<void> loadSystemPrompt(String selectedModelId) async {
    try {
      systemPrompt = await promptLoader.loadSystemPrompt();
      createAgentRunner(selectedModelId);
    } catch (e) {
      // Use fallback prompt
      systemPrompt = '''You are a helpful assistant in the ImagineApp. 
You can help users with various tasks using the tools available to you.
When showing products, use [Product(SKU)] syntax.
Be concise but friendly in your responses.''';
      createAgentRunner(selectedModelId);
    }
  }
  
  void createAgentRunner(String selectedModelId) {
    agentRunner?.dispose();
    agentRunner = AgentRunner(
      config: AgentConfig(
        model: selectedModelId,
        systemPrompt: systemPrompt,
      ),
    );
  }
  
  void dispose() {
    agentRunner?.dispose();
  }
}

