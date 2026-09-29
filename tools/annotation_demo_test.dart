// Fails on purpose, to show its annotation in CI; the next commit removes
// it.
import 'package:test/test.dart';

void main() {
  test('throws on purpose, to show its annotation in CI', () {
    throw StateError('A test of tools/ that fails on purpose.');
  });
}
