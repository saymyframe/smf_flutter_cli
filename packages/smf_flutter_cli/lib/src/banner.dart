import 'package:mason_logger/mason_logger.dart' show cyan, green;

/// What `smf` says after it created an app: where to find the community.
String get communityBanner => '''

${cyan.wrap('Created an SMF App! ✨')}
${green.wrap('''
+--------------------------------------------------------------+
| Want help or ideas? Join our Discord and meet the community! |
| Star the repo if this helped you - it motivates us ❤️        |
| Docs: https://doc.saymyframe.com                             |
| Discord: https://saymyframe.com/discord                      |
| GitHub: https://github.com/saymyframe/smf_flutter_cli        |
+--------------------------------------------------------------+''')}''';

/// What `smf` says before its first question.
const greeting = "👋 Hello! Let's create a Flutter app with Say My Frame.";
