enum MustacheSlots {
  imports._('imports'),
  bootstrap._('bootstrap'),
  routes._('routes'),
  di._('di'),
  widget._('widget');

  const MustacheSlots._(this.slot);

  final String slot;
}
