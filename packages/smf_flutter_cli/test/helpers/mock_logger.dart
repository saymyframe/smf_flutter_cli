import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';

class MockLogger extends Mock implements Logger {}

/// Progress that remembers whether it was ever finished.
class RecordingProgress extends Fake implements Progress {
  RecordingProgress(this.message);

  final String message;
  bool isFinished = false;

  @override
  void complete([String? update]) => isFinished = true;

  @override
  void fail([String? update]) => isFinished = true;

  @override
  void cancel() => isFinished = true;

  @override
  void update(String update) {}
}

/// A [MockLogger] at [Level.info] whose `progress` calls return
/// [RecordingProgress] instances collected in [progresses].
MockLogger createMockLogger({List<RecordingProgress>? progresses}) {
  final logger = MockLogger();
  when(() => logger.level).thenReturn(Level.info);
  when(() => logger.progress(any())).thenAnswer((invocation) {
    final progress = RecordingProgress(
      invocation.positionalArguments.first as String,
    );
    progresses?.add(progress);
    return progress;
  });
  return logger;
}
