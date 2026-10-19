import 'package:smf_contracts/core.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final push = TestRole<NoDsl>('push');

  group('ManualStepId', () {
    test('of a module names the module and the step', () {
      const id = ManualStepId(ModuleId('firebase_messaging'), 'apns_key');

      expect(id.module, const ModuleId('firebase_messaging'));
      expect(id.role, isNull);
      expect(id.name, 'apns_key');
      expect(id.owner, 'firebase_messaging');
      expect(id.wire, 'firebase_messaging.apns_key');
      expect('$id', 'firebase_messaging.apns_key');
    });

    test('of a role names the role and the step', () {
      final id = ManualStepId.role(push, 'ios_app_id');

      expect(id.module, isNull);
      expect(id.role, same(push));
      expect(id.name, 'ios_app_id');
      expect(id.owner, 'push');
      expect(id.wire, 'push.ios_app_id');
      expect('$id', 'push.ios_app_id');
    });

    test('compares by owner and name', () {
      const id = ManualStepId(ModuleId('firebase_messaging'), 'apns_key');
      // Another object with the same values, rather than the same constant.
      final same = ManualStepId(
        const ModuleId('firebase_messaging'),
        ['apns', '_key'].join(),
      );
      expect(identical(same, id), isFalse);
      expect(same, id);
      expect(same.hashCode, id.hashCode);
      expect({id, same}, hasLength(1));
      expect(
        const ManualStepId(ModuleId('firebase_messaging'), 'other'),
        isNot(id),
      );
      // Another module may name a step of its own the same.
      expect(
        const ManualStepId(ModuleId('firebase_auth'), 'apns_key'),
        isNot(id),
      );
      expect(id, isNot(equals('firebase_messaging.apns_key')));

      final ofRole = ManualStepId.role(push, 'ios_app_id');
      expect(ManualStepId.role(push, 'ios_app_id'), ofRole);
      expect(ManualStepId.role(push, 'ios_app_id').hashCode, ofRole.hashCode);
      // Roles compare by identity, as everywhere in the model.
      expect(
        ManualStepId.role(TestRole<NoDsl>('push'), 'ios_app_id'),
        isNot(ofRole),
      );
      // The id of a step of a module and of a step of a role differ, also
      // when they would carry one wire, which the registry rules out by
      // refusing a role with the id of a module.
      const ofModule = ManualStepId(ModuleId('push'), 'ios_app_id');
      expect(ofModule.wire, ofRole.wire);
      expect(ofModule, isNot(ofRole));
      expect(ofRole, isNot(ofModule));
    });
  });

  test('ManualStep is an id and a title, for the apps of its when', () {
    const id = ManualStepId(ModuleId('firebase_messaging'), 'apns_key');
    const step = ManualStep(id, 'Give Firebase your Apple push key');
    final withPush = ManualStep(id, 'Upload the key', when: {push});

    expect(step.id, id);
    expect(step.title, 'Give Firebase your Apple push key');
    expect(step.when, isEmpty);
    expect(step.whenChosen, isEmpty);
    expect(withPush.when, {push});
    // It takes no condition on a choice, as the pipeline lists the steps
    // before the roles choose.
    expect(withPush.whenChosen, isEmpty);
    expect(ManualStep.maxTitleLength, 80);
  });

  test('ManualSetup holds the steps of the app and the link to their guide',
      () {
    expect(ManualSetup.none.steps, isEmpty);
    expect(ManualSetup.none.link, isNull);
    // Without steps, a setup may still have a link.
    expect(ManualSetup(link: Uri.parse('https://example.com')).steps, isEmpty);

    const step = ManualStep(
      ManualStepId(ModuleId('firebase_messaging'), 'apns_key'),
      'Give Firebase your Apple push key',
    );
    final link = Uri.parse('https://example.com/setup?steps=a.b');
    final setup = ManualSetup(steps: const [step], link: link);

    expect(setup.steps, [step]);
    expect(setup.link, link);
  });
}
