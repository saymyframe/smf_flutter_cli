import 'dart:async';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';
import 'package:test/test.dart';

/// Records `<id>:start:<path>` / `<id>:end:<path>` events into a shared log.
class _RecordingStrategy implements FileWriteStrategy {
  _RecordingStrategy(this.id, this.log, {this.delay = Duration.zero});

  final String id;
  final List<String> log;
  final Duration delay;

  @override
  Future<void> write(GeneratedFile file) async {
    log.add('$id:start:${file.path}');
    await Future<void>.delayed(delay);
    log.add('$id:end:${file.path}');
  }
}

class _FailingStrategy implements FileWriteStrategy {
  @override
  Future<void> write(GeneratedFile file) async {
    throw StateError('write failed');
  }
}

void main() {
  group('CompositeWriteStrategy', () {
    const file = GeneratedFile('lib/main.dart', 'content');

    test('delegates to every strategy in order', () async {
      final log = <String>[];

      await CompositeWriteStrategy([
        _RecordingStrategy('a', log),
        _RecordingStrategy('b', log),
      ]).write(file);

      expect(log, [
        'a:start:lib/main.dart',
        'a:end:lib/main.dart',
        'b:start:lib/main.dart',
        'b:end:lib/main.dart',
      ]);
    });

    test('waits for a strategy to finish before starting the next', () async {
      final log = <String>[];

      await CompositeWriteStrategy([
        _RecordingStrategy(
          'slow',
          log,
          delay: const Duration(milliseconds: 20),
        ),
        _RecordingStrategy('fast', log),
      ]).write(file);

      expect(log.indexOf('slow:end:lib/main.dart'), 1);
      expect(log.indexOf('fast:start:lib/main.dart'), 2);
    });

    test('does nothing without strategies', () async {
      await expectLater(
        const CompositeWriteStrategy([]).write(file),
        completes,
      );
    });

    test('propagates a failure and skips the remaining strategies', () async {
      final log = <String>[];

      await expectLater(
        CompositeWriteStrategy([
          _FailingStrategy(),
          _RecordingStrategy('after', log),
        ]).write(file),
        throwsA(isA<StateError>()),
      );
      expect(log, isEmpty);
    });
  });
}
