import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _ThrowingModule extends SmfModule {
  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: ModuleId('broken'),
        description: 'Broken',
        kind: plainKind,
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      throw StateError('boom');
}

void main() {
  final used = TestRole<String>('used');
  final absent = TestRole<String>('absent');
  final code = SocketRef<CodeSocket>.role(used, 'code', const CodeSocket());

  test('collects modules, variants and role templates with origins', () {
    final templated = TestRole<String>(
      'templated',
      template: TestTemplate(
        contributions: [const PubspecContribution.hosted('a', '^1.0.0')],
      ),
    );
    final home = TestModule(
      'home',
      uses: {used, absent},
      variants: Variants(
        role: templated,
        byProvider: {
          const ModuleId('prov'): (context) => [
                const CodegenRequest(description: 'variant'),
              ],
        },
      ),
      contributions: [
        used.data('present'),
        absent.data('gone'),
        SocketContribution.code(code, const Fragment('x();')),
        const CodegenRequest(),
      ],
    );
    final provider = TestModule(
      'prov',
      providers: [RoleProvider.plain(templated), RoleProvider.plain(used)],
    );
    final resolution = Resolution([
      ResolvedModule(
        home,
        const Requested(),
        variant: const ModuleId('prov'),
      ),
      ResolvedModule(provider, const Requested()),
    ]);

    final collection = collect(resolution, testContext);

    expect(
      [for (final c in collection.all) '${c.origin}'],
      ['home', 'home', 'home', 'home', 'home (prov)', 'role:templated'],
    );
    final data = collection.all.first.contribution as RoleData<Object>;
    expect(data.origin, const ModuleOrigin(ModuleId('home')));
    final socket = collection.all[2].contribution as SocketContribution;
    expect(socket.origin, const ModuleOrigin(ModuleId('home')));
    expect(
      [for (final c in collection.all) c.applies],
      [true, false, true, true, true, true],
    );
    expect(collection.roleData.map((d) => d.value), ['present']);
    expect(collection.applyingOf<CodegenRequest>(), hasLength(2));
    expect(collection.ofModule(const ModuleId('home')), hasLength(5));
  });

  test('code for a socket of an absent role does not apply', () {
    final absentCode =
        SocketRef<CodeSocket>.role(absent, 'code', const CodeSocket());
    final module = TestModule(
      'home',
      uses: {used, absent},
      contributions: [
        SocketContribution.code(code, const Fragment('a();')),
        SocketContribution.code(absentCode, const Fragment('b();')),
        const SocketContribution.code(
          AppEntryRole.bootstrapLate,
          Fragment('c();'),
        ),
      ],
    );
    final provider = TestModule(
      'prov',
      providers: [RoleProvider.plain(used)],
    );

    final collection = collect(
      resolutionOf([scaffold(), module, provider]),
      testContext,
    );

    expect([for (final c in collection.all) c.applies], [true, false, true]);
  });

  test('when needs every listed role', () {
    final module = TestModule(
      'home',
      uses: {used, absent},
      contributions: [
        const CodegenRequest(),
        CodegenRequest(when: {used}),
        CodegenRequest(when: {used, absent}),
      ],
    );
    final provider = TestModule(
      'prov',
      providers: [RoleProvider.plain(used)],
    );

    final collection = collect(resolutionOf([module, provider]), testContext);

    expect([for (final c in collection.all) c.applies], [true, true, false]);
  });

  test('a module that fails to contribute stops generation', () {
    expect(
      () => collect(resolutionOf([_ThrowingModule()]), testContext),
      throwsA(
        isA<GenerationFailedException>()
            .having((e) => e.message, 'message', contains('broken')),
      ),
    );
  });
}
