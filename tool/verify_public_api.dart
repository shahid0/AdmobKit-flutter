import 'dart:convert';
import 'dart:io';

/// Check documentation code and forbidden API access as an external consumer.
Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  final readme = await File('${root.path}/README.md').readAsString();
  final exampleCode = await File('${root.path}/example/lib/minimal.dart').readAsString();
  final documentedExample = RegExp(r'```dart\s*\n([\s\S]*?)\n```').firstMatch(readme)?.group(1);
  if (documentedExample?.trim() != exampleCode.trim()) {
    throw StateError('The README example differs from the verified minimal app.');
  }
  final configFile = File('${root.path}/example/.dart_tool/package_config.json');
  final config = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  for (final package in packages) {
    package['rootUri'] = configFile.uri.resolve(package['rootUri'] as String).toString();
  }
  final flutter = Directory.fromUri(
    Uri.parse(packages.singleWhere((p) => p['name'] == 'flutter')['rootUri'] as String),
  );
  final dart = '${flutter.parent.parent.path}/bin/dart${Platform.isWindows ? '.bat' : ''}';
  final consumer = await Directory.systemTemp.createTemp('admob-public-api-');
  try {
    await Directory('${consumer.path}/.dart_tool').create();
    await File('${consumer.path}/.dart_tool/package_config.json').writeAsString(jsonEncode(config));
    await File(
      '${consumer.path}/pubspec.yaml',
    ).writeAsString('name: public_api_consumer\nenvironment:\n  sdk: ">=3.11.5 <4.0.0"\n');
    final good = await Directory('${consumer.path}/good').create();
    const imports = '''
// ignore_for_file: unused_import, unused_local_variable
import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter_ads_example/minimal.dart' show AppAds, ExampleApp;
''';
    var blocks = 0;
    for (final path in [
      'README.md',
      'docs/api.md',
      'docs/recipes.md',
      'docs/native-ads.md',
      'docs/setup.md',
      'docs/troubleshooting.md',
    ]) {
      final markdown = await File('${root.path}/$path').readAsString();
      for (final match in RegExp(r'```dart\s*\n([\s\S]*?)\n```').allMatches(markdown)) {
        final code = match.group(1)!.replaceAll(RegExp(r'^import [^\n]+;\n?', multiLine: true), '');
        final main = RegExp(r'\bvoid main\(').hasMatch(code) ? '' : '\nvoid main() {}\n';
        await File('${good.path}/block_${blocks++}.dart').writeAsString('$imports\n$code$main');
      }
    }
    await File(
      '${good.path}/minimal.dart',
    ).writeAsString(await File('${root.path}/example/lib/minimal.dart').readAsString());
    final positive = await Process.run(dart, [
      'analyze',
      '--format',
      'machine',
      good.path,
    ], workingDirectory: consumer.path);
    final positiveOutput = '${positive.stdout}\n${positive.stderr}';
    if (positiveOutput.contains('ERROR|') || positive.exitCode > 2) {
      throw StateError('Public documentation does not compile:\n$positiveOutput');
    }

    final bad = await Directory('${consumer.path}/bad').create();
    final forbidden = [
      'AdmobKit.pool;',
      'AdmobKit._pool;',
      'AdmobKit.activeAdSession;',
      'AdmobKit.initializeInternal();',
      'AdmobKit.currentPool;',
      'AdmobKit.currentMutex;',
      'AdmobKit.presentationMutex;',
      'AdmobKit.logger;',
      'AdmobKit.inlineAdTtl;',
      'AdmobKit.driverForTesting = null;',
      'AdmobKit.networkInfoForTesting = null;',
      'AdmobKit.setPoolForTesting(null);',
      'AdmobKit.leaseInlineAd(AppAds.native);',
      'AdmobKit.preload(AppAds.transition);',
      'AdmobKitTestHarness;',
      'activeAdSession;',
      'initializeAdSession(config: const AdmobKitConfig());',
      'disposeAdSession();',
      'adInitializationStateListenable;',
      'adSessionLogger;',
      'EagerAdPool;',
      'GoogleMobileAdsDriver;',
      'ConsentCoordinator;',
      'AdNetworkInfo;',
      'AdLogger;',
      'const AdmobKitConfig(initializeNativeGma: false);',
      'const AdmobKitConfig(retryScheduler: null);',
    ];
    final fixture = File('${bad.path}/forbidden.dart');
    const prefix =
        "import 'package:admob_kit_flutter/admob_kit_flutter.dart';\nimport 'package:flutter_ads_example/minimal.dart' show AppAds;\nvoid main() {\n";
    await fixture.writeAsString('$prefix${forbidden.join('\n')}\n}\n');
    final harnessFixture = File('${bad.path}/harness_state.dart');
    await harnessFixture.writeAsString('''
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart';
void main() {
  AdmobKitTestHarness.driver = null;
  AdmobKitTestHarness.networkInfo = null;
}
''');
    final negative = await Process.run(dart, [
      'analyze',
      '--format',
      'machine',
      bad.path,
    ], workingDirectory: consumer.path);
    final output = '${negative.stdout}\n${negative.stderr}';
    final fixturePath = await fixture.resolveSymbolicLinks();
    final harnessFixturePath = await harnessFixture.resolveSymbolicLinks();
    final errorLines = <int>{};
    final harnessErrorLines = <int>{};
    for (final line in const LineSplitter().convert(output)) {
      final fields = line.split('|');
      if (fields.length >= 8 && fields[0] == 'ERROR' && fields[1] == 'COMPILE_TIME_ERROR') {
        if (fields[3] == fixturePath) errorLines.add(int.parse(fields[4]));
        if (fields[3] == harnessFixturePath) harnessErrorLines.add(int.parse(fields[4]));
      }
    }
    for (var i = 0; i < forbidden.length; i++) {
      if (!errorLines.contains(i + 4)) throw StateError('Internal API is available: ${forbidden[i]}\n$output');
    }
    if (!harnessErrorLines.containsAll([3, 4])) {
      throw StateError('Mutable test dependency fields are still available:\n$output');
    }
    stdout.writeln(
      'Verified $blocks documentation blocks, the minimal app, ${forbidden.length} forbidden API paths, '
      'and removal of both mutable test dependency fields.',
    );
  } finally {
    await consumer.delete(recursive: true);
  }
}
