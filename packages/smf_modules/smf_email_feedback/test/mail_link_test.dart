@TestOn('vm')
library;

import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_email_feedback/smf_email_feedback.dart';
import 'package:smf_email_feedback/src/readme.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// Runs the file of the mail of an app with the module on the Dart VM: it
/// needs only Dart. Each script prints one line of JSON.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  DartDefineModule(),
  EmailFeedbackModule(),
];

/// The texts of a subject or a body that the link must carry exactly: with
/// spaces, the characters that a query takes apart, a percent sign, line
/// breaks of a mail, Ukrainian and an emoji.
const List<String> _texts = [
  'Feedback: My App',
  r'a + b = c & d? #1 100% /path\',
  'line one\r\nline two\r\n\r\nthe end',
  'Відгук: Мій застосунок',
  'Thanks \u{1F44D} for the app',
  "it's (really) *good*!",
];

void main() {
  late DartOnlyApp app;

  setUpAll(() async {
    final result = await ContractHarness(ModuleRegistry(_modules)).check(
      const ContractCase(
        'email_feedback',
        requested: [EmailFeedbackModule.id],
      ),
    );
    if (result.errors.isNotEmpty || result.app == null) {
      throw StateError('The app has errors: ${result.errors.join('\n')}');
    }
    app = DartOnlyApp.write(result.app!, const [mailFile]);
  });

  tearDownAll(() => app.delete());

  /// What [body], the body of `main()` of a script that imports the file of
  /// the mail, prints as JSON with `print(jsonEncode(...))`.
  Future<Object?> outcomeOf(String body) async => jsonDecode(
        await app.run('''
import 'dart:convert';

import 'package:contract_app/core/feedback/email_feedback_mail.dart';

void main() {
$body
}
'''),
      );

  test('needs only Dart, with nothing of the app but itself', () {
    expect(app.files, {mailFile});
  });

  test(
      'gives the link of a new mail whose subject and body come back exactly, '
      'through percent decoding and as a query, with no plus in the link',
      () async {
    final json = await outcomeOf('''
  final texts = ${jsonEncode(_texts)};
  print(jsonEncode([
    for (final text in texts)
      () {
        final link = emailFeedbackLink(
          address: 'support@example.com',
          subject: text,
          body: text,
        );
        final raw = '\$link';
        final query = raw.substring(raw.indexOf('?') + 1);
        final parts = Uri.splitQueryString(query);
        final decoded = {
          for (final part in query.split('&'))
            part.substring(0, part.indexOf('=')):
                Uri.decodeComponent(part.substring(part.indexOf('=') + 1)),
        };
        return {
          'raw': raw,
          'subject': parts['subject'],
          'body': parts['body'],
          'decoded subject': decoded['subject'],
          'decoded body': decoded['body'],
        };
      }(),
  ]));
''');
    final outcome = (json! as List<Object?>).cast<Map<String, Object?>>();

    for (final (index, text) in _texts.indexed) {
      final link = outcome[index];
      expect(
        [
          link['subject'],
          link['body'],
          link['decoded subject'],
          link['decoded body'],
        ],
        List.filled(4, text),
        reason: 'The subject and the body of the link of "$text" come back '
            'exactly as a query and through percent decoding.',
      );
      expect(
        link['raw'],
        startsWith('mailto:support@example.com?subject='),
      );
      expect(
        (link['raw']! as String).contains('+'),
        isFalse,
        reason: 'A mail app shows a + of the link as a plus: a space of '
            '"$text" is %20 in ${link['raw']}, as RFC 6068 asks, and never +, '
            'as Uri(queryParameters: ...) writes it.',
      );
    }
    expect(
      outcome[2]['raw'],
      contains('line%20one%0D%0Aline%20two'),
      reason: 'A line break of a mail is %0D%0A.',
    );
  });

  test(
      'keeps the @ of the address, encodes its plus, and gives the link of '
      'the mail of an English app on Android exactly', () async {
    final outcome = await outcomeOf(r'''
  final body = emailFeedbackBody(
    header: 'About the app and the device:',
    lines: [
      emailFeedbackAppLine(version: '1.0.0', buildNumber: '1', flavor: 'dev'),
      emailFeedbackDeviceLine(
        system: 'Android',
        systemVersion: '14',
        sdk: 34,
        manufacturer: 'Google',
        model: 'Pixel 7',
      ),
    ],
  );
  final link = emailFeedbackLink(
    address: ' feedback+tests@example.com ',
    subject: 'Feedback: $emailFeedbackAppName',
    body: body,
  );
  print(jsonEncode({
    'link': '$link',
    'path': Uri.decodeComponent(link.path),
    'scheme': link.scheme,
  }));
''');

    expect(
      outcome,
      {
        'link': 'mailto:feedback%2Btests@example.com'
            '?subject=Feedback%3A%20Contract%20App'
            '&body=%0D%0A%0D%0AAbout%20the%20app%20and%20the%20device%3A'
            '%0D%0AContract%20App%201.0.0%20(1)%2C%20dev'
            '%0D%0AAndroid%2014%20(SDK%2034)%2C%20Google%20Pixel%207',
        'path': 'feedback+tests@example.com',
        'scheme': 'mailto',
      },
      reason: 'The link goes to the address without the spaces around it, '
          'with its + as %2B and its @ as it is, and has the subject and the '
          'body with their spaces as %20.',
    );
  });

  test(
      'tells the app by its name, its version, its build number and its '
      'flavor, leaves out what is unknown, and names no flavor for a '
      'release', () async {
    final outcome = await outcomeOf('''
  print(jsonEncode([
    emailFeedbackAppName,
    emailFeedbackAppLine(version: '1.0.0', buildNumber: '1', flavor: 'dev'),
    emailFeedbackAppLine(version: '2.3.4', buildNumber: '56', flavor: 'staging'),
    emailFeedbackAppLine(version: '1.0.0', buildNumber: '1', flavor: 'prod'),
    emailFeedbackAppLine(version: ' 1.0.0 ', buildNumber: '', flavor: ''),
    emailFeedbackAppLine(buildNumber: '7'),
    emailFeedbackAppLine(),
  ]));
''');

    expect(
      outcome,
      [
        'Contract App',
        'Contract App 1.0.0 (1), dev',
        'Contract App 2.3.4 (56), staging',
        'Contract App 1.0.0 (1)',
        'Contract App 1.0.0',
        'Contract App (7)',
        'Contract App',
      ],
      reason: 'The line names the app in the case of its title, then each '
          'part that is known, and the flavor only when it is not the flavor '
          'for a release, prod, which users install from a store.',
    );
  });

  test(
      'tells the device by its system, its version and its model, does not '
      'repeat a manufacturer that the model names, and leaves out what is '
      'unknown', () async {
    final outcome = await outcomeOf('''
  print(jsonEncode([
    emailFeedbackDeviceLine(
      system: 'Android',
      systemVersion: '14',
      sdk: 34,
      manufacturer: 'Google',
      model: 'Pixel 7',
    ),
    emailFeedbackDeviceLine(
      system: 'Android',
      systemVersion: '15',
      sdk: 35,
      manufacturer: 'samsung',
      model: 'SAMSUNG SM-S911B',
    ),
    emailFeedbackDeviceLine(
      system: 'iOS',
      systemVersion: '17.4',
      model: 'iPhone 15 Pro',
    ),
    emailFeedbackDeviceLine(system: 'Android'),
    emailFeedbackDeviceLine(
      system: 'Android',
      systemVersion: ' ',
      manufacturer: 'Google',
    ),
    emailFeedbackDeviceLine(model: 'iPhone16,1'),
    emailFeedbackDeviceLine(),
  ]));
''');

    expect(outcome, [
      'Android 14 (SDK 34), Google Pixel 7',
      'Android 15 (SDK 35), SAMSUNG SM-S911B',
      'iOS 17.4, iPhone 15 Pro',
      'Android',
      'Android, Google',
      'iPhone16,1',
      '',
    ]);
  });

  test(
      'leaves two empty lines for the message, then the header and the lines '
      'that are not empty, with the line breaks of a mail', () async {
    final outcome = await outcomeOf('''
  print(jsonEncode([
    emailFeedbackBody(header: 'About:', lines: ['App 1.0.0', 'iOS 17.4']),
    emailFeedbackBody(header: 'About:', lines: ['App', '', ' ']),
  ]));
''');

    expect(outcome, [
      '\r\n\r\nAbout:\r\nApp 1.0.0\r\niOS 17.4',
      '\r\n\r\nAbout:\r\nApp',
    ]);
  });

  test(
      'takes one email address, without the spaces around it, and nothing '
      'else', () async {
    const addresses = {
      'support@example.com': true,
      ' feedback+tests@example.com ': true,
      'first.last@mail.example.co.uk': true,
      'a@b.c': true,
      '': false,
      ' ': false,
      'support': false,
      'support@example': false,
      'support@@example.com': false,
      'sup port@example.com': false,
      'support@example.com?subject=x': false,
      'a@b.com,c@d.com': false,
      'a@b.com;c@d.com': false,
      '<support@example.com>': false,
      '"support"@example.com': false,
      'support@.com': false,
      'support@example.': false,
      'support@example..com': false,
      'mailto:support@example.com': false,
      'support@example.com/x': false,
      'support#1@example.com': false,
    };
    final outcome = await outcomeOf('''
  final addresses = ${jsonEncode(addresses.keys.toList())};
  print(jsonEncode({
    for (final address in addresses)
      address: isEmailFeedbackAddress(address),
    'null': isEmailFeedbackAddress(null),
  }));
''');

    expect(outcome, {...addresses, 'null': false});
  });

  test(
      'has the name of the app in the case of its title in every app, from '
      'the name of its package', () async {
    final result = await ContractHarness(ModuleRegistry(_modules)).check(
      const ContractCase(
        'email_feedback',
        requested: [EmailFeedbackModule.id],
      ),
    );
    expect(
      result.app!.files[mailFile]!.text,
      contains(
        "const String emailFeedbackAppName = 'Contract App';\n",
      ),
    );
    expect(
      ContractHarness.defaultContext.appName,
      'contract_app',
    );
    expect(AppEntryRole.releaseFlavor.name, 'prod');
  });
}
