enum DiBindingType { singleton, factory }

class DiDependency {
  const DiDependency({
    required this.abstractType,
    required this.implementation,
    required this.bindingType,
    this.order,
  });
  final String abstractType;
  final String implementation;
  final DiBindingType bindingType;
  final int? order;
}
