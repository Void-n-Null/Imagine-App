import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'chat_thread.dart';

/// Service for persisting chat threads to local storage.
/// Uses JSON files for thread storage.
class ChatStorageService {
  static ChatStorageService? _instance;
  static ChatStorageService get instance => _instance!;
  
  late Directory _threadsDirectory;
  
  ChatStorageService._();
  
  /// Initialize the storage service. Must be called before accessing instance.
  static Future<void> initialize() async {
    if (_instance != null) return;
    
    final service = ChatStorageService._();
    
    // Get app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    service._threadsDirectory = Directory('${appDir.path}/chat_threads');
    
    // Create directory if it doesn't exist
    if (!await service._threadsDirectory.exists()) {
      await service._threadsDirectory.create(recursive: true);
    }
    
    _instance = service;
  }
  
  /// Get the file path for a thread
  File _threadFile(String threadId) {
    return File('${_threadsDirectory.path}/$threadId.json');
  }
  
  /// Save a thread to storage
  Future<void> saveThread(ChatThread thread) async {
    try {
      final file = _threadFile(thread.id);
      final json = jsonEncode(thread.toJson());
      await file.writeAsString(json);
      debugPrint('💾 Saved thread ${thread.id}: ${thread.title}');
    } catch (e) {
      debugPrint('❌ Error saving thread: $e');
      rethrow;
    }
  }
  
  /// Load a thread by ID
  Future<ChatThread?> loadThread(String threadId) async {
    try {
      final file = _threadFile(threadId);
      if (!await file.exists()) {
        return null;
      }
      
      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;
      return ChatThread.fromJson(data);
    } catch (e) {
      debugPrint('❌ Error loading thread $threadId: $e');
      return null;
    }
  }
  
  /// Delete a thread
  Future<void> deleteThread(String threadId) async {
    try {
      final file = _threadFile(threadId);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted thread $threadId');
      }
    } catch (e) {
      debugPrint('❌ Error deleting thread: $e');
      rethrow;
    }
  }
  
  /// Load all threads (returns list of thread metadata for quick loading)
  Future<List<ChatThread>> loadAllThreads() async {
    final threads = <ChatThread>[];
    
    try {
      final files = await _threadsDirectory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .toList();
      
      for (final entity in files) {
        try {
          final file = entity as File;
          final json = await file.readAsString();
          final data = jsonDecode(json) as Map<String, dynamic>;
          threads.add(ChatThread.fromJson(data));
        } catch (e) {
          debugPrint('❌ Error loading thread file ${entity.path}: $e');
        }
      }
      
      // Sort by last updated (most recent first)
      threads.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
      
      debugPrint('📂 Loaded ${threads.length} threads');
    } catch (e) {
      debugPrint('❌ Error loading threads: $e');
    }
    
    return threads;
  }
  
  /// Delete all threads
  Future<void> deleteAllThreads() async {
    try {
      final files = await _threadsDirectory.list().toList();
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
      debugPrint('🗑️ Deleted all threads');
    } catch (e) {
      debugPrint('❌ Error deleting all threads: $e');
    }
  }
}

