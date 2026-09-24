import 'package:smf_contracts/smf_contracts.dart';

// ignore: one_member_abstracts, modules implement this interface.
abstract interface class DiCodeGenerator {
  String generate(DiDependency dependency);
}
