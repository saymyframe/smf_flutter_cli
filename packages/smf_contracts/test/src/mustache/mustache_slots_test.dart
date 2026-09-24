import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('MustacheSlots', () {
    test('slot names are unique', () {
      final slots = MustacheSlots.values.map((s) => s.slot).toList();

      expect(slots.toSet(), hasLength(slots.length));
    });

    test('slot names are plain mustache identifiers', () {
      // Slots are written as {{#slot}}...{{/slot}} in brick templates.
      final identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
      for (final slot in MustacheSlots.values) {
        expect(slot.slot, matches(identifier), reason: slot.name);
      }
    });

    test('exposes the slots the DSL generators fill', () {
      expect(
        MustacheSlots.values.map((s) => s.slot),
        containsAll(<String>[
          'imports',
          'router',
          'appRoutes',
          'di',
          'tabsWidget',
        ]),
      );
    });
  });
}
