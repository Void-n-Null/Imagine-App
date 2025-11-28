import '../tool.dart';

/// A simple tool that returns the current date and time.
class GetTimeTool extends Tool {
  @override
  String get name => 'get_current_time';
  
  @override
  String get displayName => 'Getting Time...';
  
  @override
  String get description => 
      'Get the current date and time. Optionally specify a timezone offset.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'timezone_offset_hours': {
        'type': 'number',
        'description': 'Timezone offset from UTC in hours (e.g., -5 for EST, 1 for CET). Defaults to 0 (UTC).',
      },
      'format': {
        'type': 'string',
        'enum': ['iso', 'human', 'unix'],
        'description': 'Output format: "iso" for ISO 8601, "human" for readable format, "unix" for timestamp. Defaults to "human".',
      },
    },
    'required': [],
  };
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final offsetHours = (args['timezone_offset_hours'] as num?)?.toDouble() ?? 0.0;
    final format = args['format'] as String? ?? 'human';
    
    final now = DateTime.now().toUtc();
    final offset = Duration(hours: offsetHours.toInt(), minutes: ((offsetHours % 1) * 60).toInt());
    final adjusted = now.add(offset);
    
    switch (format) {
      case 'iso':
        return adjusted.toIso8601String();
      case 'unix':
        return (adjusted.millisecondsSinceEpoch ~/ 1000).toString();
      case 'human':
      default:
        final weekday = _weekdayName(adjusted.weekday);
        final month = _monthName(adjusted.month);
        final hour = adjusted.hour.toString().padLeft(2, '0');
        final minute = adjusted.minute.toString().padLeft(2, '0');
        final second = adjusted.second.toString().padLeft(2, '0');
        final tzSign = offsetHours >= 0 ? '+' : '';
        final tzLabel = offsetHours == 0 ? 'UTC' : 'UTC$tzSign${offsetHours.toStringAsFixed(0)}';
        return '$weekday, $month ${adjusted.day}, ${adjusted.year} at $hour:$minute:$second ($tzLabel)';
    }
  }
  
  String _weekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }
  
  String _monthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }
}

