enum MustacheSlots {
  imports._('imports'),
  bootstrap._('bootstrap'),
  router._('router'),
  appRoutes._('appRoutes'),
  di._('di'),
  tabsWidget._('tabsWidget'),
  pagesWidget._('pagesWidget');

  const MustacheSlots._(this.slot);

  final String slot;
}
