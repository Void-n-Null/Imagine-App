import 'dart:collection';

/// Log entry types for search debugging.
enum SearchLogType {
  request,
  response,
  error,
  info,
}

/// A single log entry for search debugging.
class SearchLogEntry {
  final DateTime timestamp;
  final SearchLogType type;
  final String message;
  final Map<String, dynamic>? data;

  SearchLogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    this.data,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get typeIcon {
    return switch (type) {
      SearchLogType.request => '→',
      SearchLogType.response => '←',
      SearchLogType.error => '✗',
      SearchLogType.info => '•',
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[$formattedTime] $typeIcon $message');
    if (data != null && data!.isNotEmpty) {
      buffer.writeln();
      for (final entry in data!.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    return buffer.toString();
  }
}

/// Singleton logger for capturing and displaying search debug events.
class SearchDebugLogger {
  static final SearchDebugLogger _instance = SearchDebugLogger._internal();
  factory SearchDebugLogger() => _instance;
  SearchDebugLogger._internal();

  static const int _maxEntries = 100;
  final Queue<SearchLogEntry> _entries = Queue<SearchLogEntry>();
  final List<void Function()> _listeners = [];

  /// Get all log entries (most recent first).
  List<SearchLogEntry> get entries => _entries.toList().reversed.toList();

  /// Get the most recent N entries.
  List<SearchLogEntry> getRecentLogs([int count = 20]) {
    final all = entries;
    return all.take(count).toList();
  }

  /// Add a listener for log updates.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Remove a listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void _addEntry(SearchLogEntry entry) {
    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    _notifyListeners();
  }

  /// Log a search request being made.
  void logRequest({
    required String query,
    required List<String> filters,
    required Map<String, String> params,
  }) {
    _addEntry(SearchLogEntry(
      timestamp: DateTime.now(),
      type: SearchLogType.request,
      message: 'Search: "${query.isEmpty ? "(all products)" : query}"',
      data: {
        'filters': filters.isEmpty ? '(none)' : filters.join(' & '),
        'sort': params['sort'] ?? 'default',
        'pageSize': params['pageSize'] ?? '10',
        'page': params['page'] ?? '1',
        if (params['show'] != null) 'attributes': params['show'],
      },
    ));
  }

  /// Log a successful search response.
  void logResponse({
    required int total,
    required int returned,
    required int pages,
    required Duration elapsed,
    List<String>? sampleCategories,
    List<String>? sampleManufacturers,
  }) {
    _addEntry(SearchLogEntry(
      timestamp: DateTime.now(),
      type: SearchLogType.response,
      message: 'Found $total products (showing $returned) in ${elapsed.inMilliseconds}ms',
      data: {
        'totalPages': pages,
        if (sampleCategories != null && sampleCategories.isNotEmpty)
          'categories': sampleCategories.take(5).join(', '),
        if (sampleManufacturers != null && sampleManufacturers.isNotEmpty)
          'manufacturers': sampleManufacturers.take(5).join(', '),
      },
    ));
  }

  /// Log an error during search.
  void logError({
    required String error,
    String? details,
  }) {
    _addEntry(SearchLogEntry(
      timestamp: DateTime.now(),
      type: SearchLogType.error,
      message: error,
      data: details != null ? {'details': details} : null,
    ));
  }

  /// Log general info.
  void logInfo(String message, [Map<String, dynamic>? data]) {
    _addEntry(SearchLogEntry(
      timestamp: DateTime.now(),
      type: SearchLogType.info,
      message: message,
      data: data,
    ));
  }

  /// Clear all log entries.
  void clear() {
    _entries.clear();
    _notifyListeners();
  }

  /// Export all logs as a formatted string for copying.
  String exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== Search Debug Log Export ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    
    for (final entry in entries.reversed) {
      buffer.writeln(entry.toString());
    }
    
    return buffer.toString();
  }
}


