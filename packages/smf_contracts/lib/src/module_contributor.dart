import 'package:smf_contracts/smf_contracts.dart';

abstract interface class IModuleCodeContributor {
  List<BrickContribution> get brickContributions;

  List<Contribution> get sharedFileContributions;

  ModuleDescriptor get moduleDescriptor;

  List<DiDependencyGroup> get di;

  RouteGroup get routes;
}

mixin EmptyModuleCodeContributor implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => const [];

  @override
  List<Contribution> get sharedFileContributions => const [];

  @override
  List<DiDependencyGroup> get di => const [];

  @override
  RouteGroup get routes => RouteGroup.empty();
}
