import 'package:smf_contracts/smf_contracts.dart';

class RouteScreen {
  const RouteScreen(this.className, {this.screenArguments = const []});

  final String className;
  final List<RouteScreenArgs> screenArguments;
}
