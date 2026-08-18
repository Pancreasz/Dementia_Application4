import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/recording_sink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Under flutter_test `dart.library.js_interop` is absent, so the conditional
  // import in recording_sink.dart resolves to the io implementation. The web
  // one cannot be exercised here at all — see the source guard below, which is
  // the only automated protection the browser path has.
  group('io sink', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('moca-sink-test');

      // path_provider is a plugin; under flutter_test there is no platform
      // behind its channel, so newTarget() would fail on a MissingPlugin
      // rather than on anything this code did.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async =>
            call.method == 'getTemporaryDirectory' ? tmp.path : null,
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'), null);
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('reads the recording back and then deletes it', () async {
      final file = File('${tmp.path}/take.wav');
      await file.writeAsBytes([1, 2, 3, 4]);

      final bytes = await PlatformRecordingSink().readAndRelease(file.path);

      expect(bytes, [1, 2, 3, 4]);
      // Nine subtests per session; leaving each take behind fills the temp
      // directory with patient audio nobody ever collects.
      expect(file.existsSync(), isFalse);
    });

    test('returns nothing rather than throwing when stop() gave no handle',
        () async {
      // AudioRecorder.stop() returns null if it was never started — during a
      // skip, for instance. That must not surface as an error, or a skip turns
      // into the error screen it was pressed to escape.
      expect(await PlatformRecordingSink().readAndRelease(null), isEmpty);
      expect(await PlatformRecordingSink().readAndRelease(''), isEmpty);
    });

    test('returns nothing when the file is gone', () async {
      expect(
        await PlatformRecordingSink().readAndRelease('${tmp.path}/missing.wav'),
        isEmpty,
      );
    });

    test('newTarget hands back a distinct .wav path each take', () async {
      final sink = PlatformRecordingSink();
      final a = await sink.newTarget();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = await sink.newTarget();

      expect(a, endsWith('.wav'));
      expect(a, isNot(b));
    });
  });

  group('web-safety source guard', () {
    // dart:io and path_provider COMPILE for the web and throw only when
    // touched, so no build failure and no widget test catches their return.
    // The symptom is every voice subtest erroring at runtime in the browser —
    // which is exactly the state this app shipped in before 2026-08-18.
    test('nothing in lib/moca imports dart:io or path_provider directly', () {
      final offenders = <String>[];

      for (final entity in Directory('lib/moca').listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The io sink is *supposed* to; it is the branch the web build drops.
        if (entity.path.endsWith('_io.dart')) continue;

        final source = entity.readAsStringSync();
        if (source.contains("import 'dart:io'") ||
            source.contains('package:path_provider')) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'These compile on the web and throw at runtime. Put the '
            'platform-specific half in recording_sink_io.dart instead.',
      );
    });
  });
}
