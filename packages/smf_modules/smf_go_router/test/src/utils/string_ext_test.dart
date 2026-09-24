import 'package:smf_go_router/src/utils/string_ext.dart';
import 'package:test/test.dart';

void main() {
  group('StringExt.camelCase', () {
    test('joins words split by non-alphanumeric characters', () {
      expect('user-profile'.camelCase(), 'userProfile');
      expect('settings_about'.camelCase(), 'settingsAbout');
      expect('Home Screen'.camelCase(), 'homeScreen');
      expect('/orders/:id'.camelCase(), 'ordersId');
      expect('  padded  words  '.camelCase(), 'paddedWords');
    });

    test('lowercases an all-caps word', () {
      expect('HTTP client'.camelCase(), 'httpClient');
    });

    test('keeps digits inside words', () {
      expect('tab 2 view'.camelCase(), 'tab2View');
      expect('x1y2'.camelCase(), 'x1y2');
    });

    test('returns an empty string when there are no words', () {
      expect(''.camelCase(), '');
      expect('--/'.camelCase(), '');
    });

    test(
      'keeps the word boundaries of an already camelCased string',
      () {
        expect('homeScreen'.camelCase(), 'homeScreen');
        expect('userProfile'.camelCase(), 'userProfile');
      },
    );

    test('splits camelCased words, acronyms included', () {
      expect('HomeScreen'.camelCase(), 'homeScreen');
      expect('HTTPClient'.camelCase(), 'httpClient');
      expect('userID'.camelCase(), 'userId');
      expect('tab2View'.camelCase(), 'tab2View');
      expect('/orders/:orderId'.camelCase(), 'ordersOrderId');
    });
  });
}
