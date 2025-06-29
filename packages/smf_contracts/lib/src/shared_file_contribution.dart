import 'package:mason/mason.dart';

enum SharableCodeSlots {
  imports._('imports'),
  bootstrap._('bootstrap'),
  routes._('routes'),
  di._('di'),
  services._('services'),
  providers._('providers'),
  config._('config'),
  utils._('utils');

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
  final String slot;
  final String content;
  final int? order;
  final Map<String, dynamic>? vars;
}

class SharedFileContributionGroup {
  const SharedFileContributionGroup({
    required this.bundle,
    required this.contributions,
  });

  final MasonBundle bundle;
  final List<SharedFileContribution> contributions;
}
