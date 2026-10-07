import 'dart:io';

/// Public guides are the source for installed skill references.
Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--check')) {
    stderr.writeln('Usage: dart run tool/sync_skill.dart [--check]');
    exitCode = 64;
    return;
  }
  final root = File.fromUri(Platform.script).parent.parent;
  final check = args.contains('--check');
  final files = <String, String>{
    '.agents/skills/flutter-ads/SKILL.md': 'skills/flutter-ads/SKILL.md',
    for (final name in ['api', 'recipes', 'native-ads', 'setup', 'troubleshooting']) ...{
      'skills/flutter-ads/reference/$name.md': 'docs/$name.md',
      '.agents/skills/flutter-ads/reference/$name.md': 'docs/$name.md',
    },
  };
  var stale = false;
  for (final entry in files.entries) {
    var content = await File('${root.path}/${entry.value}').readAsString();
    if (entry.value.startsWith('docs/')) {
      content = content.replaceAll('../README.md', 'https://github.com/shahid0/AdmobKit-flutter/blob/main/README.md');
      content = content.replaceAll(
        'assets/native-template-catalog.png',
        'https://raw.githubusercontent.com/shahid0/AdmobKit-flutter/main/docs/assets/native-template-catalog.png',
      );
    }
    final output = File('${root.path}/${entry.key}');
    if (await output.exists() && await output.readAsString() == content) continue;
    if (check) {
      stderr.writeln('Outdated skill reference: ${entry.key}');
      stale = true;
    } else {
      await output.parent.create(recursive: true);
      await output.writeAsString(content);
    }
  }
  if (stale) exitCode = 1;
}
