import 'dart:io';

class FileStats {
  final String path;
  final int lineCount;
  final int classCount;
  final int widgetCount;

  FileStats({
    required this.path,
    required this.lineCount,
    required this.classCount,
    required this.widgetCount,
  });
}

void main(List<String> args) {
  // You can adjust which directories to scan here
  final root = Directory('.');
  final directoriesToScan = <String>['lib', 'test'];

  final stats = <FileStats>[];

  for (final entry in root.listSync(recursive: true, followLinks: false)) {
    if (entry is! File) continue;
    if (!entry.path.endsWith('.dart')) continue;

    final relativePath = entry.path.replaceFirst(root.path, '').replaceFirst(RegExp(r'^/'), '');

    // Only include files under the selected directories
    if (!directoriesToScan.any((dir) => relativePath.startsWith('$dir/'))) {
      continue;
    }

    final content = entry.readAsStringSync();
    final lines = content.split('\n');

    final lineCount = lines.length;

    // Simple regex heuristics; not a full Dart parser but good enough for analysis
    final classRegExp = RegExp(r'\bclass\s+\w+');
    final classCount = classRegExp.allMatches(content).length;

    // Heuristic: count occurrences of "Widget" type declarations and common widget patterns
    final widgetTypeRegExp = RegExp(r'\b\w+Widget\b');
    final buildMethodRegExp = RegExp(r'Widget\s+build\s*\(');

    final widgetCount = widgetTypeRegExp.allMatches(content).length +
        buildMethodRegExp.allMatches(content).length;

    stats.add(FileStats(
      path: relativePath,
      lineCount: lineCount,
      classCount: classCount,
      widgetCount: widgetCount,
    ));
  }

  // Sort by line count descending
  stats.sort((a, b) => b.lineCount.compareTo(a.lineCount));

  // Print header
  const pathCol = 'Path';
  const linesCol = 'Lines';
  const classesCol = 'Classes';
  const widgetsCol = 'Widgets';

  print(
      '${pathCol.padRight(80)} | ${linesCol.padLeft(7)} | ${classesCol.padLeft(7)} | ${widgetsCol.padLeft(7)}');
  print('-' * 80 + ' | ' + '-' * 7 + ' | ' + '-' * 7 + ' | ' + '-' * 7);

  for (final s in stats) {
    print(
        '${s.path.padRight(80)} | ${s.lineCount.toString().padLeft(7)} | ${s.classCount.toString().padLeft(7)} | ${s.widgetCount.toString().padLeft(7)}');
  }
}
