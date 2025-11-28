import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Manages a queue of status messages to be displayed sequentially
/// with a minimum duration for each message.
class StatusQueueManager extends ChangeNotifier {
  final Queue<String> _queue = Queue<String>();
  String? _currentStatus;
  Timer? _timer;
  bool _isProcessing = false;
  
  // Configuration
  final Duration minDisplayDuration;
  
  StatusQueueManager({
    this.minDisplayDuration = const Duration(milliseconds: 500),
  });
  
  /// The current status message to display
  String? get currentStatus => _currentStatus;
  
  /// Add a status message to the queue
  void addStatus(String status) {
    // Avoid duplicate consecutive statuses
    if (_queue.isNotEmpty && _queue.last == status) return;
    if (_queue.isEmpty && _currentStatus == status) return;
    
    _queue.add(status);
    _processQueue();
  }
  
  /// Clear the queue and current status
  void clear() {
    _queue.clear();
    _currentStatus = null;
    _timer?.cancel();
    _timer = null;
    _isProcessing = false;
    notifyListeners();
  }
  
  /// Start processing the queue
  void _processQueue() {
    if (_isProcessing) return;
    
    if (_queue.isEmpty) {
      // Nothing to show
      return;
    }
    
    _isProcessing = true;
    _showNext();
  }
  
  void _showNext() {
    if (_queue.isEmpty) {
      _isProcessing = false;
      return;
    }
    
    _currentStatus = _queue.removeFirst();
    notifyListeners();
    
    // Wait for minimum duration before showing next
    _timer?.cancel();
    _timer = Timer(minDisplayDuration, () {
      _showNext();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

