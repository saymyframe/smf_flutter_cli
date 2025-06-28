class ModuleDescriptor {
  const ModuleDescriptor({
    required this.name,
    required this.description,
    this.dependsOn = const [],
    this.pubDependency = const [],
  });

  final String name;
  final String description;
  final List<String> dependsOn;
  final List<String> pubDependency;
}
