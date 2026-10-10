@TestOn('vm')
library;

import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_sign_in/smf_sign_in.dart';
import 'package:test/test.dart';

import 'support/providers.dart';

/// A feature of the tests whose screen can start the app.
const _feed = StartFeature('feed');

/// The modules of the tests: flutter_core, which creates the app,
/// go_router, which routes it and asks the guards of the module, the two
/// modules that manage state, sign-in with accounts in memory, gen_l10n,
/// which provides the localization role, with the preferences that it
/// requires, a feature that can start the app, and this module.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BlocModule(),
  RiverpodModule(),
  MemoryAuthModule(),
  SharedPreferencesModule(),
  GenL10nModule(),
  _feed,
  SignInModule(),
];

void main() {
  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the app of the module with each state manager', () {
      expect(
        [
          for (final result in results)
            if (result.contractCase.name.startsWith('sign_in'))
              result.contractCase.name,
        ],
        [
          'sign_in (bloc) with localization',
          'sign_in (riverpod) with localization',
          'sign_in (bloc)',
          'sign_in (riverpod)',
        ],
      );
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });
  });
}
