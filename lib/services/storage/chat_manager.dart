import 'package:flutter/foundation.dart';
import '../agent/chat_message.dart';
import '../bestbuy/models/product.dart';
import 'chat_storage_service.dart';
import 'chat_thread.dart';
import 'settings_service.dart';

/// Manages chat threads and provides a centralized API for chat functionality.
/// This is the main interface for the chat UI to interact with.
class ChatManager extends ChangeNotifier {
  static ChatManager? _instance;
  static ChatManager get instance => _instance!;
  
  final ChatStorageService _storage;
  final SettingsService _settings;
  
  /// All loaded threads
  List<ChatThread> _threads = [];
  
  /// Currently active thread
  ChatThread? _currentThread;
  
  /// Loading state
  bool _isLoading = true;
  
  /// Pending product to attach to chat input (consumed by ChatPage)
  BestBuyProduct? _pendingProductAttachment;
  
  ChatManager._(this._storage, this._settings);
  
  /// Initialize the chat manager. Must be called after storage and settings are initialized.
  static Future<void> initialize() async {
    if (_instance != null) return;
    
    final manager = ChatManager._(
      ChatStorageService.instance,
      SettingsService.instance,
    );
    
    await manager._loadThreads();
    _instance = manager;
  }
  
  /// Load all threads from storage
  Future<void> _loadThreads() async {
    _isLoading = true;
    notifyListeners();
    
    _threads = await _storage.loadAllThreads();
    
    // Try to restore last active thread
    final lastActiveId = _settings.lastActiveThreadId;
    if (lastActiveId != null) {
      _currentThread = _threads.where((t) => t.id == lastActiveId).firstOrNull;
    }
    
    // If no valid last active thread, use most recent or create new
    if (_currentThread == null && _threads.isNotEmpty) {
      _currentThread = _threads.first;
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // ============ Getters ============
  
  bool get isLoading => _isLoading;
  
  List<ChatThread> get threads => List.unmodifiable(_threads);
  
  ChatThread? get currentThread => _currentThread;
  
  BestBuyProduct? get pendingProductAttachment => _pendingProductAttachment;
  
  /// Get the current thread, or create one if none exists
  ChatThread getOrCreateCurrentThread() {
    if (_currentThread == null) {
      createNewThread();
    }
    return _currentThread!;
  }
  
  // ============ Thread Management ============
  
  /// Create a new empty thread and set it as current
  ChatThread createNewThread({BestBuyProduct? initialProduct}) {
    final thread = ChatThread(
      initialProductSku: initialProduct?.sku,
    );
    
    if (initialProduct != null) {
      thread.title = 'About: ${initialProduct.name.length > 30 ? '${initialProduct.name.substring(0, 30)}...' : initialProduct.name}';
    }
    
    _threads.insert(0, thread);
    _currentThread = thread;
    
    _saveCurrentThread();
    _settings.setLastActiveThreadId(thread.id);
    _settings.addThreadToOrder(thread.id);
    
    notifyListeners();
    return thread;
  }
  
  /// Switch to a different thread
  Future<void> switchToThread(String threadId) async {
    final thread = _threads.where((t) => t.id == threadId).firstOrNull;
    if (thread != null) {
      _currentThread = thread;
      await _settings.setLastActiveThreadId(threadId);
      await _settings.moveThreadToFront(threadId);
      notifyListeners();
    }
  }
  
  /// Delete a thread
  Future<void> deleteThread(String threadId) async {
    _threads.removeWhere((t) => t.id == threadId);
    await _storage.deleteThread(threadId);
    await _settings.removeThreadFromOrder(threadId);
    
    // If we deleted the current thread, switch to another
    if (_currentThread?.id == threadId) {
      _currentThread = _threads.isNotEmpty ? _threads.first : null;
      await _settings.setLastActiveThreadId(_currentThread?.id);
    }
    
    notifyListeners();
  }
  
  /// Clear all threads
  Future<void> clearAllThreads() async {
    _threads.clear();
    _currentThread = null;
    await _storage.deleteAllThreads();
    await _settings.setLastActiveThreadId(null);
    await _settings.setThreadOrder([]);
    notifyListeners();
  }
  
  // ============ Message Management ============
  
  /// Add a message to the current thread
  void addMessage(ChatMessage message) {
    if (_currentThread == null) {
      createNewThread();
    }
    
    // If this is a tool result, mark the corresponding tool call as completed
    if (message.role == MessageRole.tool && message.toolCallId != null) {
      _currentThread!.markToolCallCompleted(message.toolCallId!);
    }
    
    _currentThread!.addMessage(message);
    _saveCurrentThread();
    notifyListeners();
  }
  
  /// Add multiple messages to the current thread
  void addMessages(List<ChatMessage> messages) {
    if (_currentThread == null) {
      createNewThread();
    }
    
    for (final message in messages) {
      _currentThread!.addMessage(message);
    }
    _saveCurrentThread();
    notifyListeners();
  }
  
  /// Save the current thread to storage
  Future<void> _saveCurrentThread() async {
    if (_currentThread != null) {
      await _storage.saveThread(_currentThread!);
    }
  }
  
  /// Force save (call after streaming completes, etc.)
  Future<void> saveCurrentThread() async {
    await _saveCurrentThread();
  }
  
  /// Update thread title
  Future<void> updateThreadTitle(String threadId, String newTitle) async {
    final thread = _threads.where((t) => t.id == threadId).firstOrNull;
    if (thread != null) {
      thread.title = newTitle;
      await _storage.saveThread(thread);
      notifyListeners();
    }
  }
  
  // ============ Product Attachment ============
  
  /// Set a product to be attached to the chat input (consumed by ChatPage)
  void setPendingProductAttachment(BestBuyProduct product) {
    _pendingProductAttachment = product;
    notifyListeners();
  }
  
  /// Clear the pending attachment (called after ChatPage consumes it)
  void clearPendingProductAttachment() {
    _pendingProductAttachment = null;
  }
}

