import 'package:smf_contracts/lego_core.dart';

/// A role for tests, configured through its constructor.
final class TestRole<D extends Object> extends Role<D> {
  TestRole(
    this.id, {
    this.cardinality = RoleCardinality.atMostOne,
    Set<Role> requires = const {},
    Set<Role> uses = const {},
    this.sockets = const [],
    this.options = const [],
    this.template,
    this.moduleRules = const [],
    this.structuralRules = const [],
  })  : _requires = requires,
        _uses = uses;

  @override
  final String id;

  @override
  String get description => 'Test role $id';

  @override
  final RoleCardinality cardinality;

  final Set<Role> _requires;
  final Set<Role> _uses;

  @override
  Set<Role> get requires => _requires;

  @override
  Set<Role> get uses => _uses;

  @override
  final List<SocketRef> sockets;

  @override
  final List<RoleOption> options;

  @override
  final RoleTemplate<D>? template;

  @override
  final List<ModuleRule<D>> moduleRules;

  @override
  final List<StructuralRule<D>> structuralRules;
}

/// A role that overrides nothing but what it must, to test the defaults.
final class MinimalRole extends Role<NoDsl> {
  const MinimalRole();

  @override
  String get id => 'minimal';

  @override
  String get description => 'Minimal';

  @override
  RoleCardinality get cardinality => RoleCardinality.many;
}

/// A module for tests with a fixed descriptor.
final class TestModule extends SmfModule {
  const TestModule(this.descriptor);

  @override
  final ModuleDescriptor descriptor;
}

/// A kind without rules, for tests.
const plainKind = ModuleKind(id: 'plain', label: 'Plain');

/// The context of a test app.
const testContext = ModuleContext(
  appName: 'my_app',
  orgName: 'com.example',
  appIdentity: AppIdentity(
    androidApplicationId: 'com.example.my_app',
    iosBundleId: 'com.example.my-app',
    androidNamespace: 'com.example.my_app',
  ),
);

/// An environment that fails on anything but its flags.
final class FakeEnvironment implements SmfEnvironment {
  FakeEnvironment({this.interactive = false});

  @override
  final bool interactive;

  @override
  bool get skipExternalSetup => false;

  @override
  HostOperatingSystem get operatingSystem => HostOperatingSystem.linux;

  @override
  SmfProcessRunner get processRunner => throw UnimplementedError();

  @override
  SmfPrompter get prompter => throw UnimplementedError();

  @override
  SmfLogger get logger => throw UnimplementedError();

  @override
  Future<String?> findExecutable(String name) async => null;

  @override
  Future<String> writeTempFile(String name, String contents) async =>
      '/tmp/$name';
}
