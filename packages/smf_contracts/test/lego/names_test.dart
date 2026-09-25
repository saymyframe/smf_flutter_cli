import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

void main() {
  group('SmfNames.isSnakeCase', () {
    test('accepts lower snake_case names', () {
      for (final name in ['a', 'go_router', 'firebase_core', 'v2', 'a_1_b']) {
        expect(SmfNames.isSnakeCase(name), isTrue, reason: name);
      }
    });

    test('rejects names that cannot become tags or identifiers', () {
      // A double underscore separates the parts of a tag.
      for (final name in [
        '',
        'Go_router',
        'go-router',
        'go.router',
        '_private',
        'trailing_',
        'double__underscore',
        '1st',
        'with space',
      ]) {
        expect(SmfNames.isSnakeCase(name), isFalse, reason: name);
      }
    });
  });

  group('SmfNames case conversion', () {
    test('converts snake_case to camelCase', () {
      expect(SmfNames.lowerCamelCase('firebase_core'), 'firebaseCore');
      expect(SmfNames.upperCamelCase('firebase_core'), 'FirebaseCore');
      expect(SmfNames.lowerCamelCase('home'), 'home');
      expect(SmfNames.upperCamelCase('app_v2'), 'AppV2');
    });

    test('returns an empty name unchanged', () {
      expect(SmfNames.lowerCamelCase(''), '');
      expect(SmfNames.upperCamelCase(''), '');
    });
  });

  group('ModuleId', () {
    test('compares and hashes by name, also as a constant map key', () {
      const constant = ModuleId('go_router');
      final parsed = ModuleId.parse(['go', 'router'].join('_'));

      expect(parsed, constant);
      expect(const {ModuleId('bloc'): 1}[ModuleId.parse('bloc')], 1);
    });

    test('prints as the plain name', () {
      expect('${const ModuleId('go_router')}', 'go_router');
      expect(const ModuleId('go_router').value, 'go_router');
    });

    test('parse rejects invalid ids with a FormatException', () {
      expect(() => ModuleId.parse('Go-Router'), throwsFormatException);
      expect(ModuleId.isValid('go_router'), isTrue);
      expect(ModuleId.isValid('go__router'), isFalse);
    });

    test('derives Dart identifiers', () {
      const id = ModuleId('firebase_analytics');
      expect(id.lowerCamelCase, 'firebaseAnalytics');
      expect(id.upperCamelCase, 'FirebaseAnalytics');
    });
  });
}
