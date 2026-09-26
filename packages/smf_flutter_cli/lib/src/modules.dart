import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_riverpod/smf_riverpod.dart';

/// The modules that `smf create` offers.
///
/// A run in a terminal asks first which of the modules without a role the
/// app has, one question for each kind, such as its features, and then which
/// module provides each role: the roles in the order they first appear in
/// this list, each after the roles whose providers require it, such as the
/// layout before the router. Each question lists its modules in the order of
/// this list, and an answer keeps that order.
const List<SmfModule> smfModules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BlocModule(),
  RiverpodModule(),
  HomeModule(),
  BottomTabsModule(),
  GetItModule(),
];
