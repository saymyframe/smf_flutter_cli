enum DiImportAnchor {
  coreService._('lib/core/services/'),
  coreModel._('lib/core/models/'),
  coreUtil._('lib/core/utils/'),
  coreRepo._('lib/core/repositories/');

  const DiImportAnchor._(this.path);

  final String path;
}
