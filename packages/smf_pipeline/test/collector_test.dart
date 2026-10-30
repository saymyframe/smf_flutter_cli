import 'package:smf_contracts/smf_contracts.dart';
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
      resolutionOf([scaffold(bricks: false), module, provider]),
      testContext,
    );

    // The scaffold contributes the minimum iOS version, the SDK constraint
    // and the dependency on Flutter first, and the template of the app
    // entry role its brick, its note for coding agents, its widget for the
    // icons of the status bar, the dependencies on Flutter and on flutter_test
    // of the widget and its test, and the section of the README on the
    // flavors last.
    expect(
      [for (final c in collection.all) c.applies],
      [
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
      ],
    );
  });

  test('a step by hand of a role applies only with the role', () {
    final ofUsed = ManualStep(ManualStepId.role(used, 'key'), 'Upload a key');
    final ofAbsent = ManualStep(ManualStepId.role(absent, 'key'), 'Sign it');
    const ofModule = ManualStep(ManualStepId(ModuleId('home'), 'id'), 'Do it');
    final withAbsent = ManualStep(
      const ManualStepId(ModuleId('home'), 'other'),
      'Do it too',
      when: {absent},
    );
    final module = TestModule(
      'home',
      uses: {used, absent},
      contributions: [ofUsed, ofAbsent, ofModule, withAbsent],
    );
    final provider = TestModule(
      'prov',
      providers: [RoleProvider.plain(used)],
    );

    final collection = collect(resolutionOf([module, provider]), testContext);

    expect(
      [
        for (final collected in collection.ofModule(const ModuleId('home')))
          collected.applies,
      ],
      [true, false, true, false],
    );
    expect(
      [
        for (final collected in collection.applyingOf<ManualStep>())
          collected.contribution,
      ],
      [ofUsed, ofModule],
    );
    // The step is collected as it is, with its origin beside it.
    expect(collection.all.first.contribution, same(ofUsed));
    expect(collection.all.first.fromHook, isFalse);
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

  test(
      'applies a contribution with conditions on what roles chose by the '
      'roles alone, until the choices decide it', () {
    final clock = TestRole<String>('clock');
    final twelve = ChoiceCondition(
      clock,
      'the clock shows 12 hours',
      holdsFor: (choice) => choice == '12',
      withoutRole: false,
    );
    final dial = BrickContribution(
      bundle('dial', paths: ['lib/dial.dart']),
      whenChosen: {twelve},
    );
    final module = TestModule(
      'face',
      uses: {used, absent, clock},
      contributions: [
        dial,
        used.data('always'),
        used.data('noon', whenChosen: {twelve}),
        // It does not apply by the roles, whatever the clock chose.
        absent.data('gone', whenChosen: {twelve}),
      ],
    );
    final provider = TestModule(
      'prov',
      providers: [RoleProvider.plain(used), RoleProvider.plain(clock)],
    );
    final resolution = resolutionOf([module, provider]);
    final collection = collect(resolution, testContext);
    const issue = SmfIssue('kept');
    final withIssue = Collection(collection.all, issues: const [issue]);

    expect(
      [for (final c in collection.all) c.applies],
      [true, true, true, false],
    );

    final twelveHours = withIssue.decide(
      {clock: '12'},
      resolution.presentRoles,
    );
    expect(
      [for (final c in twelveHours.all) c.applies],
      [true, true, true, false],
    );
    expect(twelveHours.roleData.map((data) => data.value), ['always', 'noon']);
    expect(twelveHours.issues, [issue]);

    final twentyFourHours = withIssue.decide(
      {clock: '24'},
      resolution.presentRoles,
    );
    expect(
      [for (final c in twentyFourHours.all) c.applies],
      [false, true, false, false],
    );
    expect(twentyFourHours.applyingOf<BrickContribution>(), isEmpty);
    expect(twentyFourHours.roleData.map((data) => data.value), ['always']);
    // Every contribution stays, with its origin and its kind.
    expect(twentyFourHours.all.first.contribution, same(dial));
    expect(
      twentyFourHours.all.first.origin,
      const ModuleOrigin(ModuleId('face')),
    );
    expect(twentyFourHours.issues, [issue]);

    // Without the clock, the condition holds as it says.
    expect(
      [
        for (final c in withIssue.decide(const {}, {used}).all) c.applies,
      ],
      [false, true, false, false],
    );
  });

  test('keeps whether a render hook returned a contribution it decides', () {
    final clock = TestRole<String>('clock');
    final never = ChoiceCondition(
      clock,
      'never',
      holdsFor: (choice) => false,
      withoutRole: true,
    );
    final collection = Collection([
      Collected(
        RoleData<String>(clock, 'from a hook', whenChosen: {never}),
        const ModuleOrigin(ModuleId('face')),
        applies: true,
        fromHook: true,
      ),
    ]);

    final decided = collection.decide({clock: 'x'}, {clock}).all.single;
    expect(decided.applies, isFalse);
    expect(decided.fromHook, isTrue);
  });

  test('a module that fails to contribute gets an issue', () {
    final collection = collect(
      resolutionOf([_ThrowingModule(), TestModule('fine')]),
      testContext,
    );

    expect(collection.all, isEmpty);
    expect(
      collection.issues.single.message,
      'broken failed to contribute: Bad state: boom',
    );
    expect(
      collection.issues.single.origin,
      const ModuleOrigin(ModuleId('broken')),
    );
  });
}
