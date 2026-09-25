import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/src/shell.dart';
import 'package:test/test.dart';

void main() {
  test('quotes what a POSIX shell treats specially', () {
    String quoted(String argument) =>
        shellQuoted(argument, HostOperatingSystem.macos);

    expect(quoted('--platforms=android,ios'), '--platforms=android,ios');
    expect(quoted('lib/my options.dart'), "'lib/my options.dart'");
    expect(quoted(r'$HOME'), r"'$HOME'");
    expect(quoted("it's"), r"'it'\''s'");
    expect(quoted(r'C:\x'), r"'C:\x'");
  });

  test('quotes for PowerShell and cmd on Windows', () {
    String quoted(String argument) =>
        shellQuoted(argument, HostOperatingSystem.windows);

    expect(quoted(r'C:\work\my_app'), r'C:\work\my_app');
    expect(quoted(r'C:\work\my apps'), r'"C:\work\my apps"');
    expect(quoted('--platforms=android,ios'), '"--platforms=android,ios"');
    expect(quoted('%PATH%'), '"%PATH%"');
  });
}
