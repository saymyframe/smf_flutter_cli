import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A step of [module] that runs the tool [name], with the id [id] if it is
/// given, which continues the step [of] if that is given.
Collected _step(
  String module,
  String name, {
  PostGenStepId? id,
  PostGenStepId? of,
}) =>
    Collected(
      PostGenStep(ToolRef(name), const [], id: id, followUpOf: of),
      ModuleOrigin(ModuleId(module)),
      applies: true,
    );

/// [steps] as the tools of their steps, each followed by the steps that
/// continue it in brackets.
List<String> _tree(List<BoundStep> steps) => [
      for (final bound in steps)
        bound.followUps.isEmpty
            ? bound.step.tool.executable
            : '${bound.step.tool.executable} ${_tree(bound.followUps)}',
    ];

void main() {
  const configure = PostGenStepId(ModuleId('core'), 'configure');
  const fix = PostGenStepId(ModuleId('crash'), 'fix');

  test(
      'binds each step to the step it continues, in the order of the steps, '
      'and keeps the other steps in their order', () {
    final steps = [
      _step('core', 'configure', id: configure),
      _step('other', 'build'),
      _step('crash', 'fix', id: fix, of: configure),
      _step('crash', 'check', of: fix),
      _step('crash', 'tidy', of: configure),
    ];

    final bound = bindSteps(steps);

    expect(_tree(bound), [
      'configure [fix [check], tidy]',
      'build',
    ]);
    expect(bound.first.origin, const ModuleOrigin(ModuleId('core')));
    expect(
      bound.first.followUps.first.origin,
      const ModuleOrigin(ModuleId('crash')),
    );
    // Each step once, in the order they run.
    expect(
      [for (final step in bound) ...step.all],
      [steps[0], steps[2], steps[3], steps[4], steps[1]],
    );
  });

  test(
      'leaves out the steps that continue a step which is not among them, '
      'with the steps that continue them, and steps that continue each '
      'other', () {
    const a = PostGenStepId(ModuleId('crash'), 'a');
    const b = PostGenStepId(ModuleId('crash'), 'b');
    const self = PostGenStepId(ModuleId('crash'), 'self');

    final bound = bindSteps([
      // Its step does not apply to the app, so the steps have no step
      // with the id that it continues.
      _step('crash', 'fix', id: fix, of: configure),
      _step('crash', 'check', of: fix),
      _step('crash', 'a', id: a, of: b),
      _step('crash', 'b', id: b, of: a),
      _step('crash', 'self', id: self, of: self),
      _step('other', 'build'),
    ]);

    expect(_tree(bound), ['build']);
  });

  test('binds a step to the first step with the id that it continues', () {
    final bound = bindSteps([
      _step('core', 'first', id: configure),
      _step('core', 'second', id: configure),
      _step('crash', 'fix', of: configure),
    ]);

    expect(_tree(bound), ['first [fix]', 'second']);
  });
}
