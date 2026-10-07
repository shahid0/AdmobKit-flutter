import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public documentation compiles and internal APIs are compile-time errors', () async {
    final result = await Process.run('dart', ['run', 'tool/verify_public_api.dart']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('installed skill references match the public guides', () async {
    final result = await Process.run('dart', ['run', 'tool/sync_skill.dart', '--check']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
