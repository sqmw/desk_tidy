import 'dart:io';

class LocSummary {
  int files = 0;
  int totalLines = 0;
  int blankLines = 0;
  int commentLines = 0;
  int codeLines = 0;
}

void main(List<String> args) {
  final targetDir = args.isNotEmpty ? args.first : 'lib';
  final dir = Directory(targetDir);
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exitCode = 2;
    return;
  }

  final summary = LocSummary();
  final dartFiles = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in dartFiles) {
    summary.files++;
    _countFile(file, summary);
  }

  stdout.writeln('Target: ${dir.path}');
  stdout.writeln('Dart files: ${summary.files}');
  stdout.writeln('Total lines: ${summary.totalLines}');
  stdout.writeln('Code lines: ${summary.codeLines}');
  stdout.writeln('Comment lines: ${summary.commentLines}');
  stdout.writeln('Blank lines: ${summary.blankLines}');
}

void _countFile(File file, LocSummary summary) {
  final lines = file.readAsLinesSync();
  var inBlockComment = false;

  for (final line in lines) {
    summary.totalLines++;
    final t = line.trim();
    if (t.isEmpty) {
      summary.blankLines++;
      continue;
    }

    if (inBlockComment) {
      summary.commentLines++;
      final endIdx = t.indexOf('*/');
      if (endIdx >= 0) {
        inBlockComment = false;
        final rest = t.substring(endIdx + 2).trim();
        if (rest.isNotEmpty && !rest.startsWith('//')) {
          summary.codeLines++;
        }
      }
      continue;
    }

    if (t.startsWith('//')) {
      summary.commentLines++;
      continue;
    }

    if (t.startsWith('/*')) {
      summary.commentLines++;
      final endIdx = t.indexOf('*/');
      if (endIdx < 0) {
        inBlockComment = true;
        continue;
      }
      final rest = t.substring(endIdx + 2).trim();
      if (rest.isNotEmpty && !rest.startsWith('//')) {
        summary.codeLines++;
      }
      continue;
    }

    summary.codeLines++;
  }
}
