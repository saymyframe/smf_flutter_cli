enum RouteImportAnchor {
  features._('lib/features/'),
  coreService._('lib/core/services/'),
  coreRepo._('lib/core/repositories/');

  const RouteImportAnchor._(this.path);

  final String path;
}
