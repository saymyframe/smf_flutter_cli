class ModuleDescriptor {
  const ModuleDescriptor({
    required this.name,
    required this.description,
    this.dependsOn = const {},
    this.pubDependency = const {},
    this.pubDevDependency = const {},
  });

  final String name;
  final String description;
  final Set<String> dependsOn;
  final Set<String> pubDependency;
  final Set<String> pubDevDependency;
}
