import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sharable_bricks/src/sharable_slots.dart';

class SharableSlotsRegistry {
  List<SharedCodeSlot> get all => [
    ...BootstrapSharedCodeSlots().all,
    ...CoreDiSharedCodeSlots().all,
  ];
}
