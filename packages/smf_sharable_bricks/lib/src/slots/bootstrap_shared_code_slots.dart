import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sharable_bricks/src/slots/i_sharable_slots.dart';

class BootstrapSharedCodeSlots implements ISharableSlots {
  static final imports = SharedCodeSlot(
    tag: SharableCodeSlots.imports.slot,
    filePath: 'lib/main.dart',
    description: 'Add necessary imports for main.dart file',
  );

  static final bootstrap = SharedCodeSlot(
    tag: SharableCodeSlots.bootstrap.slot,
    filePath: 'lib/main.dart',
    description:
        'Add initialization needed to be done in main.dart file. '
        'For example Firebase.initializeApp()',
  );

  @override
  List<SharedCodeSlot> get all => [imports, bootstrap];
}
