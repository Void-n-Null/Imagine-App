import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting app settings.
/// Handles caching and persistence of user preferences.
class SettingsService {
  static SettingsService? _instance;
  static SettingsService get instance => _instance!;
  
  final SharedPreferences _prefs;
  
  // Settings keys
  static const String _keySelectedModel = 'selected_model';
  static const String _keyLastActiveThreadId = 'last_active_thread_id';
  static const String _keyThreadOrder = 'thread_order';
  static const String _keySkippedUpdateVersion = 'skipped_update_version';
  static const String _keyDontRemindMeForUpdates = 'dont_remind_me_for_updates';
  
  // In-memory cache for frequently accessed settings
  String? _selectedModelCache;
  String? _lastActiveThreadIdCache;
  List<String>? _threadOrderCache;
  String? _skippedUpdateVersionCache;
  bool? _dontRemindMeForUpdatesCache;
  
  SettingsService._(this._prefs) {
    // Initialize cache from stored values
    _selectedModelCache = _prefs.getString(_keySelectedModel);
    _lastActiveThreadIdCache = _prefs.getString(_keyLastActiveThreadId);
    _threadOrderCache = _prefs.getStringList(_keyThreadOrder);
    _skippedUpdateVersionCache = _prefs.getString(_keySkippedUpdateVersion);
    _dontRemindMeForUpdatesCache = _prefs.getBool(_keyDontRemindMeForUpdates);
  }
  
  /// Initialize the settings service. Must be called before accessing instance.
  static Future<void> initialize() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    _instance = SettingsService._(prefs);
  }
  
  // ============ Model Selection ============
  
  /// Get the currently selected model ID
  String get selectedModel => _selectedModelCache ?? 'openai/gpt-4o-mini';
  
  /// Set the selected model ID
  Future<void> setSelectedModel(String modelId) async {
    _selectedModelCache = modelId;
    await _prefs.setString(_keySelectedModel, modelId);
  }
  
  // ============ Thread Management ============
  
  /// Get the last active thread ID
  String? get lastActiveThreadId => _lastActiveThreadIdCache;
  
  /// Set the last active thread ID
  Future<void> setLastActiveThreadId(String? threadId) async {
    _lastActiveThreadIdCache = threadId;
    if (threadId != null) {
      await _prefs.setString(_keyLastActiveThreadId, threadId);
    } else {
      await _prefs.remove(_keyLastActiveThreadId);
    }
  }
  
  /// Get the order of threads (for sorting in UI)
  List<String> get threadOrder => _threadOrderCache ?? [];
  
  /// Set the thread order
  Future<void> setThreadOrder(List<String> order) async {
    _threadOrderCache = order;
    await _prefs.setStringList(_keyThreadOrder, order);
  }
  
  /// Add a thread to the order (at the beginning for most recent)
  Future<void> addThreadToOrder(String threadId) async {
    final order = List<String>.from(threadOrder);
    order.remove(threadId); // Remove if exists
    order.insert(0, threadId); // Add at beginning
    await setThreadOrder(order);
  }
  
  /// Remove a thread from the order
  Future<void> removeThreadFromOrder(String threadId) async {
    final order = List<String>.from(threadOrder);
    order.remove(threadId);
    await setThreadOrder(order);
  }
  
  /// Move a thread to the front (most recent)
  Future<void> moveThreadToFront(String threadId) async {
    await addThreadToOrder(threadId);
  }
  
  // ============ Update Preferences ============
  
  /// Get the version that the user chose to skip
  String? get skippedUpdateVersion => _skippedUpdateVersionCache;
  
  /// Set the version to skip (user chose "No Thanks")
  Future<void> setSkippedUpdateVersion(String? version) async {
    _skippedUpdateVersionCache = version;
    if (version != null) {
      await _prefs.setString(_keySkippedUpdateVersion, version);
    } else {
      await _prefs.remove(_keySkippedUpdateVersion);
    }
  }
  
  /// Check if user has disabled update reminders entirely
  bool get dontRemindMeForUpdates => _dontRemindMeForUpdatesCache ?? false;
  
  /// Set whether to remind user about updates
  Future<void> setDontRemindMeForUpdates(bool value) async {
    _dontRemindMeForUpdatesCache = value;
    await _prefs.setBool(_keyDontRemindMeForUpdates, value);
  }
}

