enum DiBindingType { singleton, factory }

class DiDependency {
  final String abstractType;
  final String implementation;
  final DiBindingType bindingType;
  final int? order;

  const DiDependency({
    required this.abstractType,
    required this.implementation,
    required this.bindingType,
    this.order,
  });
}
