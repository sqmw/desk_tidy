import 'dart:io';

import 'package:desk_tidy/utils/desktop_helper.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final writePngs = args.contains('--write');
  final outDir = Directory(p.join('build', 'icon_check'));
  if (writePngs) {
    outDir.createSync(recursive: true);
    stdout.writeln('Will write PNGs to: ${outDir.path}');
  }

  final desktopPath = await getDesktopPath();
  stdout.writeln('Desktop path: $desktopPath');

  final shortcuts = await scanDesktopShortcuts(desktopPath, showHidden: true);
  if (shortcuts.isEmpty) {
    stdout.writeln('No shortcuts found.');
    return;
  }

  var success = 0;
  var written = 0;
  final requestedSize = writePngs ? 256 : 96;
  for (final shortcut in shortcuts) {
    final iconBytes = extractIcon(shortcut, size: requestedSize);
    final isOk = iconBytes != null && iconBytes.isNotEmpty;
    final result = isOk ? 'OK' : 'FAIL';
    stdout.writeln('$result: $shortcut');
    if (isOk) success++;

    if (writePngs && isOk && written < 20) {
      final base = p.basenameWithoutExtension(shortcut);
      final safe = base.replaceAll(RegExp(r'[<>:"/\\\\|?*]'), '_');
      final outFile = File(p.join(outDir.path, '$safe.png'));
      outFile.writeAsBytesSync(iconBytes!);
      written++;
    }
  }

  stdout.writeln(
    'Extracted icons for $success / ${shortcuts.length} desktop entries.',
  );
  if (writePngs) {
    stdout.writeln('Wrote $written PNG(s) to: ${outDir.path}');
  }
}
