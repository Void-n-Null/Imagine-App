import 'package:flutter/material.dart';
import '../config/api_keys.dart';
import '../services/agent/agent.dart';
import '../services/bestbuy/bestbuy.dart';
import '../services/comparison/comparison.dart';
import '../services/openrouter/openrouter_auth_page.dart';
import '../services/openrouter/openrouter_auth_service.dart';
import '../services/openrouter/openrouter_models.dart';
import '../services/storage/storage.dart';
import '../theme/app_colors.dart';
import 'cart_page.dart';
import 'scan_product_page.dart';
import 'chat/chat_agent_manager.dart';
import 'chat/chat_app_bar.dart';
import 'chat/chat_empty_state.dart';
import 'chat/chat_input_area.dart';
import 'chat/chat_message_bubble.dart';
import 'chat/chat_model_manager.dart';
import 'chat/chat_thinking_indicator.dart';
import 'chat/chat_thread_indicator.dart';
import 'chat/model_selector_sheet.dart';
import 'chat/thread_selector_sheet.dart';
import 'chat/status_queue_manager.dart';
import 'chat/tool_call_debug_modal.dart';
import 'app_info_modal.dart';
import 'settings_page.dart';
import 'product_comparison_page.dart';

/// Set to true to show tool call debug button in the UI.
/// This allows viewing the exact tool calls and their results.
const bool kShowToolCallDebug = false;

class ChatPage extends StatefulWidget {
  /// Optional product to attach to the first message
  final BestBuyProduct? initialProduct;
  
  const ChatPage({super.key, this.initialProduct});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late final OpenRouterAuthService _authService;
  late final BestBuyClient _bestBuyClient;
  late final ChatManager _chatManager;
  late final SettingsService _settings;
  late final ChatModelManager _modelManager;
  late final ChatAgentManager _agentManager;
  late final StatusQueueManager _statusManager;
  late final ScanRequestService _scanRequestService;
  
  bool _isAuthenticated = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isNavigatingToScan = false; // Prevent duplicate navigations
  
  // Product attachment for "Ask AI" feature
  BestBuyProduct? _attachedProduct;
  
  /// Get messages from current thread
  List<ChatMessage> get _messages => 
      _chatManager.currentThread?.messages ?? [];
  
  /// Filter messages for display (hide system, tool result messages, and empty assistant messages)
  List<ChatMessage> get _visibleMessages => 
      _messages.where((m) {
        if (m.role == MessageRole.system || m.role == MessageRole.tool) return false;
        if (m.role == MessageRole.assistant && m.content.isEmpty) return false;
        return true;
      }).toList();
  
  /// Check if we're in landing state (no messages yet)
  bool get _isLandingState => _visibleMessages.isEmpty;

  @override
  void initState() {
    super.initState();
    _authService = OpenRouterAuthService();
    _bestBuyClient = BestBuyClient(apiKey: ApiKeys.bestBuy);
    _chatManager = ChatManager.instance;
    _settings = SettingsService.instance;
    _modelManager = ChatModelManager(
      modelsService: OpenRouterModelsService(),
      settings: _settings,
    );
    _agentManager = ChatAgentManager(
      promptLoader: PromptLoader(),
    );
    _statusManager = StatusQueueManager();
    _scanRequestService = ScanRequestService.instance;
    
    // Initialize attached product from navigation
    _attachedProduct = widget.initialProduct;
    
    // If we have an initial product, create a new thread for it
    if (widget.initialProduct != null) {
      _chatManager.createNewThread(initialProduct: widget.initialProduct);
    }
    
    // Listen for chat manager changes
    _chatManager.addListener(_onChatManagerChanged);
    
    // Listen for scan requests from AI tools
    _scanRequestService.addListener(_onScanRequestChanged);
    
    // Register tools
    _registerTools();
    
    _initialize();
  }
  
  /// Handle scan request service changes
  void _onScanRequestChanged() {
    if (!mounted) return;
    
    // If there's an active scan request and we're not already navigating, go to scanner
    if (_scanRequestService.hasActiveRequest && !_isNavigatingToScan) {
      _navigateToScannerForRequest();
    }
  }
  
  /// Navigate to scanner page for an AI-requested scan
  void _navigateToScannerForRequest() {
    _isNavigatingToScan = true;
    
    final request = _scanRequestService.activeRequest;
    if (request == null) {
      _isNavigatingToScan = false;
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScanProductPage(),
        settings: RouteSettings(
          arguments: ScanRequestArgs(request: request),
        ),
      ),
    ).then((_) {
      // Reset navigation flag when returning
      _isNavigatingToScan = false;
    });
  }
  
  void _onChatManagerChanged() {
    if (mounted) {
      // Check for pending product attachment
      final pending = _chatManager.pendingProductAttachment;
      if (pending != null) {
        _attachedProduct = pending;
        _chatManager.clearPendingProductAttachment();
      }
      setState(() {});
      _scrollToBottom();
    }
  }
  
  void _clearAttachment() {
    setState(() {
      _attachedProduct = null;
    });
  }
  
  Future<void> _initialize() async {
    await _checkAuthStatus();
    await _agentManager.loadSystemPrompt(_modelManager.selectedModelId);
    await _modelManager.loadModels();
    if (mounted) setState(() {});
    
    setState(() => _isInitialized = true);
  }

  void _registerTools() {
    final registry = ToolRegistry.instance;
    
    // Clear any existing tools (in case of hot reload)
    registry.clear();
    
    // Register available tools
    registry.register(GetTimeTool());
    registry.register(SearchProductsTool(client: _bestBuyClient));
    registry.register(AnalyzeProductTool(client: _bestBuyClient));
    registry.register(RequestScanTool());
    
    // Cart tools
    registry.register(AddToCartTool(client: _bestBuyClient));
    registry.register(RemoveFromCartTool());
    registry.register(ClearCartTool());
    registry.register(ViewCartTool());
    
    // Comparison tools
    registry.register(CompareProductsTool(client: _bestBuyClient));
  }
  

  @override
  void dispose() {
    _chatManager.removeListener(_onChatManagerChanged);
    _scanRequestService.removeListener(_onScanRequestChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _agentManager.dispose();
    _modelManager.dispose();
    _statusManager.dispose();
    _bestBuyClient.close();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final key = await _authService.getApiKey();
    if (mounted) {
      setState(() {
        _isAuthenticated = key != null;
      });
    }
  }
  
  void _showToolCallsDebug() {
    final toolCalls = extractToolCallsWithResults(_messages);
    if (toolCalls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tool calls in this conversation')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ToolCallsListModal(toolCalls: toolCalls),
    );
  }
  
  void _showThreadSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ThreadSelectorSheet(
        threads: _chatManager.threads,
        currentThreadId: _chatManager.currentThread?.id,
        onThreadSelected: (thread) async {
          await _chatManager.switchToThread(thread.id);
          if (mounted) {
            Navigator.pop(context);
          }
        },
        onNewThread: () {
          _chatManager.createNewThread();
          Navigator.pop(context);
        },
        onDeleteThread: (threadId) async {
          await _chatManager.deleteThread(threadId);
        },
        isAuthenticated: _isAuthenticated,
        onConnectOpenRouter: () {
          Navigator.pop(context);
          _connectOpenRouter();
        },
        onDisconnectOpenRouter: () {
          Navigator.pop(context);
          _disconnectOpenRouter();
        },
      ),
    );
  }

  Future<void> _connectOpenRouter() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const OpenRouterAuthPage(),
      ),
    );
    
    if (result == true) {
      await _checkAuthStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully connected to OpenRouter!')),
        );
      }
    }
  }

  Future<void> _disconnectOpenRouter() async {
    await _authService.logout();
    await _checkAuthStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from OpenRouter')),
      );
    }
  }

  void _navigateToScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScanProductPage(),
      ),
    );
  }

  void _navigateToCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CartPage(),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          models: _modelManager.modelsToShow,
          selectedModelId: _modelManager.selectedModelId,
          isLoadingModels: _modelManager.isLoading,
          onRefreshModels: () async {
            await _modelManager.loadModels();
            if (mounted) setState(() {});
          },
          onModelSelected: (model) async {
            await _settings.setSelectedModel(model.id);
            _agentManager.createAgentRunner(model.id);
            if (mounted) setState(() {});
          },
          isAuthenticated: _isAuthenticated,
          onAuthChanged: () async {
            await _checkAuthStatus();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _navigateToComparison() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProductComparisonPage(),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isProcessing || _agentManager.agentRunner == null) return;
    
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to OpenRouter first')),
      );
      return;
    }
    
    // Ensure we have a thread
    _chatManager.getOrCreateCurrentThread();
    
    // Capture attached product before clearing
    final attachedProduct = _attachedProduct;
    final attachedSku = attachedProduct?.sku;
    
    // Create messages for the conversation
    if (attachedProduct != null) {
      // Add hidden context message with product info (for AI)
      _chatManager.addMessage(ChatMessage.system(
        'The user is asking about the following product:\n\n${attachedProduct.toAIContext()}'
      ));
    }
    
    // Create user message with optional product attachment (for visual display)
    _chatManager.addMessage(ChatMessage.user(text, attachedProductSku: attachedSku));
    
    setState(() {
      _attachedProduct = null; // Clear attachment after sending
      _isProcessing = true;
    });
    _inputController.clear();
    _scrollToBottom();
    
    // Build the message context for the agent
    // Include all messages except the last user message (run() adds it separately)
    final allMessages = _chatManager.currentThread!.messages;
    final previousMessages = allMessages.sublist(0, allMessages.length - 1);
    
    // Run the agent with the full context
    try {
      _statusManager.clear();
      _statusManager.addStatus("Thinking...");
      
      await for (final message in _agentManager.agentRunner!.run(previousMessages, text)) {
        if (!mounted) return;
        
        // Update status if tool calls are present
        if (message.role == MessageRole.assistant && 
            message.toolCalls != null && 
            message.toolCalls!.isNotEmpty) {
          for (final toolCall in message.toolCalls!) {
            _statusManager.addStatus(ToolRegistry.instance.getDisplayName(toolCall.name));
          }
        }
        
        _chatManager.addMessage(message);
        _scrollToBottom();
      }
      
      // Save thread after completion
      await _chatManager.saveCurrentThread();
    } catch (e) {
      if (mounted) {
        _chatManager.addMessage(ChatMessage.assistant('Sorry, an error occurred: $e'));
      }
    } finally {
      if (mounted) {
        _statusManager.clear();
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isLandingState ? _buildLandingAppBar() : buildChatAppBar(
        context: context,
        onThreadSelectorTap: _showThreadSelector,
        onNewChat: () {
          _chatManager.createNewThread();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Started new chat')),
          );
        },
        onScanProduct: _navigateToScanner,
        onOpenCart: _navigateToCart,
        onOpenSettings: _navigateToSettings,
        onOpenComparison: _navigateToComparison,
      ),
      body: _isLandingState
          ? ChatEmptyState(
              isAuthenticated: _isAuthenticated,
              onConnectOpenRouter: _connectOpenRouter,
              inputController: _inputController,
              onSendMessage: _sendMessage,
              isProcessing: _isProcessing,
            )
          : _buildChatBody(),
    );
  }
  
  /// Build a minimal app bar for landing state
  PreferredSizeWidget _buildLandingAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        tooltip: 'Menu',
        onPressed: _showThreadSelector,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: _navigateToSettings,
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan Product',
          onPressed: _navigateToScanner,
        ),
        // Comparison button with badge
        _LandingComparisonButton(onPressed: _navigateToComparison),
        // Cart button with badge
        _LandingCartButton(onPressed: _navigateToCart),
      ],
    );
  }
  
  /// Build the chat body with messages and input
  Widget _buildChatBody() {
    return Column(
      children: [
        // Thread indicator bar with optional debug button
        if (_chatManager.currentThread != null)
          Row(
            children: [
              Expanded(
                child: ChatThreadIndicator(
                  thread: _chatManager.currentThread!,
                  totalThreads: _chatManager.threads.length,
                  onTap: _showThreadSelector,
                ),
              ),
              // Tool call debug button
              if (kShowToolCallDebug)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(
                      Icons.bug_report_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'View Tool Calls',
                    onPressed: _showToolCallsDebug,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        
        // Messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _visibleMessages.length + (_isProcessing ? 1 : 0),
            cacheExtent: 10000,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              // Show thinking indicator at the end while processing
              if (_isProcessing && index == _visibleMessages.length) {
                return ListenableBuilder(
                  listenable: _statusManager,
                  builder: (context, _) {
                    return ChatThinkingIndicator(
                      status: _statusManager.currentStatus,
                    );
                  },
                );
              }
              
              return ChatMessageBubble(
                message: _visibleMessages[index],
                client: _bestBuyClient,
              );
            },
          ),
        ),
        
        // Input area (only when not in landing state)
        ChatInputArea(
          inputController: _inputController,
          isProcessing: _isProcessing,
          attachedProduct: _attachedProduct,
          onClearAttachment: _clearAttachment,
          onSendMessage: _sendMessage,
        ),
      ],
    );
  }
}

/// Comparison icon button with item count badge for landing page
class _LandingComparisonButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _LandingComparisonButton({required this.onPressed});

  @override
  State<_LandingComparisonButton> createState() => _LandingComparisonButtonState();
}

class _LandingComparisonButtonState extends State<_LandingComparisonButton> {
  final ComparisonService _comparison = ComparisonService.instance;

  @override
  void initState() {
    super.initState();
    _comparison.addListener(_onComparisonChanged);
  }

  @override
  void dispose() {
    _comparison.removeListener(_onComparisonChanged);
    super.dispose();
  }

  void _onComparisonChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _comparison.itemCount;
    
    return IconButton(
      icon: Badge(
        isLabelVisible: itemCount > 0,
        label: Text(
          itemCount > 99 ? '99+' : itemCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: AppColors.secondaryBlue,
        textColor: AppColors.background,
        child: const Icon(Icons.compare_outlined),
      ),
      tooltip: 'Product Comparison',
      onPressed: widget.onPressed,
    );
  }
}

/// Cart icon button with item count badge for landing page
class _LandingCartButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _LandingCartButton({required this.onPressed});

  @override
  State<_LandingCartButton> createState() => _LandingCartButtonState();
}

class _LandingCartButtonState extends State<_LandingCartButton> {
  final CartService _cart = CartService.instance;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _cart.itemCount;
    
    return IconButton(
      icon: Badge(
        isLabelVisible: itemCount > 0,
        label: Text(
          itemCount > 99 ? '99+' : itemCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: AppColors.accentYellow,
        textColor: AppColors.background,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
      tooltip: 'Shopping Cart',
      onPressed: widget.onPressed,
    );
  }
}
