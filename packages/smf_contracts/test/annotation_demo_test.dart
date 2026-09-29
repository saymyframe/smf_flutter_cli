// Fails on purpose, to show its annotation in CI; the next commit removes
// it.
import 'package:test/test.dart';

void main() {
  test('fails on purpose, to show its annotation in CI', () {
    expect(1, 2);
  });
}
