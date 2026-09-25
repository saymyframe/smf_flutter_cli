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

  group('SmfNames.isDartIdentifier', () {
    test('accepts identifiers that are not reserved words', () {
      for (final name in ['id', 'userId', r'$x', '_private', 'HomeScreen']) {
        expect(SmfNames.isDartIdentifier(name), isTrue, reason: name);
      }
    });

    test('rejects reserved words and malformed names', () {
      for (final name in ['class', 'new', 'await', 'yield', '', '1a', 'a-b']) {
        expect(SmfNames.isDartIdentifier(name), isFalse, reason: name);
      }
      expect(SmfNames.reservedWords, contains('switch'));
    });
  });

  group('SmfNames.snakeCaseOf', () {
    test('splits camelCase words, keeping digits with the word before', () {
      expect(SmfNames.snakeCaseOf('HomeScreen'), 'home_screen');
      expect(SmfNames.snakeCaseOf('userId'), 'user_id');
      expect(SmfNames.snakeCaseOf('HTTPClient'), 'http_client');
      expect(SmfNames.snakeCaseOf('Screen2'), 'screen2');
      expect(SmfNames.snakeCaseOf('ID'), 'id');
      expect(SmfNames.snakeCaseOf('a'), 'a');
    });

    test('always returns a valid snake_case name', () {
      for (final name in ['A2B', 'HTTP2Client', 'aB', 'ABc', 'x1Y2']) {
        expect(
          SmfNames.isSnakeCase(SmfNames.snakeCaseOf(name)),
          isTrue,
          reason: name,
        );
      }
    });

    test('rejects names that are not letters and digits', () {
      for (final name in ['', '_Home', '1st', r'a$b', 'a_b']) {
        expect(() => SmfNames.snakeCaseOf(name), throwsArgumentError);
      }
    });
  });

  group('SmfNames.dartString', () {
    test('quotes text and escapes what Dart would interpret', () {
      expect(SmfNames.dartString('Home'), "'Home'");
      expect(SmfNames.dartString("It's"), r"'It\'s'");
      expect(SmfNames.dartString(r'$5 \ x'), r"'\$5 \\ x'");
      expect(SmfNames.dartString('a\nb\tc'), r"'a\nb\tc'");
      expect(SmfNames.dartString('\x01'), r"'\x01'");
    });

    test('keeps non-ASCII text, which mason renders unchanged', () {
      final literal = SmfNames.dartString('Головна');

      expect(literal, "'Головна'");
      expect(Fragment.hasStrippedBackslash(literal), isFalse);
    });

    test('escapes a non-ASCII character after a backslash', () {
      final literal = SmfNames.dartString(r'a\é');

      expect(literal, r"'a\\\u{e9}'");
      expect(Fragment.hasStrippedBackslash(literal), isFalse);
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
