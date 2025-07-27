enum RouteImportAnchor {
  features._('lib/features/'),
  coreService._('lib/core/services/'),
  coreRepo._('lib/core/repositories/'),
  coreWidgets._('lib/core/widgets/');

  const RouteImportAnchor._(this.path);

  final String path;
}
