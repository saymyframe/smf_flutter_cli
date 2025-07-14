import 'package:mason/mason.dart';

enum SharableCodeSlots {
  imports._('imports'),
  bootstrap._('bootstrap'),
  routes._('routes'),
  di._('di'),
  widget._('widget');

  const SharableCodeSlots._(this.slot);

  final String slot;
}

class SharedFileContribution {
  const SharedFileContribution({
    required this.bundle,
    required this.slot,
    required this.content,
    this.order,
    this.vars,
  });

  final MasonBundle bundle;
  final SharedCodeSlot slot;
  final String content;
  final int? order;
  final Map<String, dynamic>? vars;
}

class SharedCodeSlot {
  const SharedCodeSlot({
    required this.tag,
    required this.filePath,
    required this.description,
  });

  final String tag;
  final String filePath;
  final String description;
}
