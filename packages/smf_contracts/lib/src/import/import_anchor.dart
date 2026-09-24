enum ImportAnchor {
  coreService._('lib/core/services/'),
  coreModel._('lib/core/models/'),
  coreUtil._('lib/core/utils/'),
  coreRepo._('lib/core/repositories/'),
  coreWidgets._('lib/core/widgets/'),
  features._('lib/features/');

  const ImportAnchor._(this.path);

  final String path;
}
