import 'package:args/command_runner.dart';

final class SetupCommand extends Command<void> {
  @override
  String get description => 'Setup in existing project';

  @override
  String get name => 'setup';
}
