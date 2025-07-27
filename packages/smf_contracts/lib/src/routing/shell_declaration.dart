import 'package:smf_contracts/smf_contracts.dart';

enum ShellType { tabBar, pageView }

class ShellDeclaration {
  const ShellDeclaration({
    required this.id,
    required this.type,
    required this.screen,
    required this.widgetFilePath,
  });

  final String id;
  final ShellType type;
  final RouteScreen screen;
  final String widgetFilePath;
}
