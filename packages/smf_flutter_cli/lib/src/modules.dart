import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_riverpod/smf_riverpod.dart';

/// The modules that `smf create` offers, in the order it offers them.
const List<SmfModule> smfModules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BlocModule(),
  RiverpodModule(),
  HomeModule(),
];
