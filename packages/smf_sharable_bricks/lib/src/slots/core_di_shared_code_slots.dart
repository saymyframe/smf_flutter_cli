import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sharable_bricks/src/slots/i_sharable_slots.dart';

class CoreDiSharedCodeSlots implements ISharableSlots {
  static final imports = SharedCodeSlot(
    tag: SharableCodeSlots.imports.slot,
    filePath: 'lib/core/di/core_di.dart',
    description: 'Add necessary imports for core dependency injection file',
  );

  static final di = SharedCodeSlot(
    tag: SharableCodeSlots.di.slot,
    filePath: 'lib/core/di/core_di.dart',
    description: 'Register dependency using di system',
  );

  static final homeWidget = SharedCodeSlot(
    tag: SharableCodeSlots.widget.slot,
    filePath: 'lib/feature/home/home_screen.dart',
    description: 'Widget for the home screen',
  );

  @override
  List<SharedCodeSlot> get all => [imports, di, homeWidget];
}
