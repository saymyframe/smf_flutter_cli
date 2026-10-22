@TestOn('vm')
library;

import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_paywall/smf_paywall.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:test/test.dart';

import 'support/dart_app.dart';
import 'support/providers.dart';

/// The modules of the tests: flutter_core, which creates the app,
/// go_router, which routes it and asks the guard of the module, the two
/// modules that manage state, purchases in memory, dart_define, which
/// provides the env role, the settings module, and this module.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BlocModule(),
  RiverpodModule(),
  MemoryPurchasesModule(),
  DartDefineModule(),
  SettingsModule(),
  PaywallModule(),
];

/// The directory of the files of the module in the app.
const _folder = 'lib/features/paywall';

/// The files of the module that need no more of Flutter than its
/// foundation: the values of the state, the texts that depend on a plan,
/// the links, and the function of the guard.
const _state = '$_folder/paywall_state.dart';
const _texts = '$_folder/paywall_texts.dart';
const _links = '$_folder/paywall_links.dart';
const _guards = '$_folder/paywall_guards.dart';

/// The variants of the module, each with the id of its state manager, the
/// package that it imports, and the files of its state.
const List<({ModuleId id, String package, List<String> stateFiles})> _variants =
    [
  (
    id: PaywallModule.blocVariant,
    package: 'flutter_bloc',
    stateFiles: [
      '$_folder/paywall_composition.dart',
      '$_folder/paywall_cubit.dart',
      '$_folder/subscription_cubit.dart',
      '$_folder/premium_cubit.dart',
    ],
  ),
  (
    id: PaywallModule.riverpodVariant,
    package: 'flutter_riverpod',
    stateFiles: [
      '$_folder/purchases_provider.dart',
      '$_folder/paywall_notifier.dart',
    ],
  ),
];

/// The names of the reasons of a failure of purchases, in their order.
const _reasons = [
  'network',
  'pending',
  'alreadyOwned',
  'notAllowed',
  'unavailable',
  'storeProblem',
  'notConfigured',
  'unknown',
];

/// The app of the module with the state manager [variant], with purchases
/// in memory and without the localization role, so that its texts are the
/// English ones as literals.
Future<RenderedApp> _rendered(ModuleId variant) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(
      'paywall with $variant',
      requested: const [PaywallModule.id, MemoryPurchasesModule.id],
      picks: {stateManagementRole: variant},
    ),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError('The app has errors: ${result.errors.join('\n')}');
  }
  return result.app!;
}

/// [text] with a no-break space in place of each space.
String _noBreak(String text) => text.replaceAll(' ', '\u00A0');

/// The import of the file of the app at [path].
String _import(String path) =>
    'package:contract_app/${path.substring('lib/'.length)}';

/// What every script of the state starts with: a service of purchases that
/// the script scripts, a controller of purchases started with it, and the
/// state of the paywall as a scenario sees it.
const _prelude = r'''
const yearly = Plan(
  id: 'yearly',
  title: 'Yearly',
  price: r'$29.99',
  amount: 29.99,
  currencyCode: 'USD',
  period: BillingPeriod(1, BillingUnit.year),
);
const monthly = Plan(
  id: 'monthly',
  title: 'Monthly',
  price: r'$4.99',
  amount: 4.99,
  currencyCode: 'USD',
  period: BillingPeriod(1, BillingUnit.month),
);
const premium = PremiumAccess(renews: true);

final class Scripted implements PurchasesService {
  final StreamController<AppAccess> _changes = StreamController.broadcast();

  AppAccess now = const NoAccess();
  List<Plan> offer = const [monthly, yearly];
  PurchasesFailure? plansFailure;
  PurchasesFailure? failure;
  AppAccess? purchaseAnswer = premium;
  Completer<void>? hold;
  Completer<void>? holdPlans;
  final List<String> calls = [];

  /// The access changes without a call of the app, as when it ends.
  void tell(AppAccess access) {
    now = access;
    _changes.add(access);
  }

  Future<void> _call(String call) async {
    calls.add(call);
    await hold?.future;
    if (failure case final failure?) throw failure;
  }

  @override
  Future<void> identify(String? userId) async {}

  @override
  Future<AppAccess> access() async => now;

  @override
  Stream<AppAccess> get accessChanges => _changes.stream;

  @override
  Future<List<Plan>> plans() async {
    calls.add('plans');
    await holdPlans?.future;
    if (plansFailure case final failure?) throw failure;
    return offer;
  }

  @override
  Future<AppAccess?> purchase(Plan plan) async {
    await _call('purchase ${plan.id}');
    if (purchaseAnswer case final answer?) now = answer;
    return purchaseAnswer;
  }

  @override
  Future<AppAccess> restore() async {
    await _call('restore');
    return now;
  }
}

/// A controller of purchases started with [service].
Future<AppPurchasesController> purchasesOf(Scripted service) async {
  final purchases = AppPurchasesController();
  await purchases.start(service);
  return purchases;
}

String show(PaywallState state) => [
  if (state.loading) 'loading',
  if (state.plans case final plans?)
    'plans ${plans.map((plan) => plan.id).join(' ')}',
  if (state.loadFailure case final failure?) 'load failed ${failure.reason.name}',
  if (state.selected case final plan?) 'selected ${plan.id}',
  if (state.busy case final action?) 'busy ${action.name}',
  if (state.failure case final failure?) 'failed ${failure.reason.name}',
  if (state.notice case final notice?) 'notice ${notice.name}',
].join(', ');

/// Lets what waits for a microtask or for a timer of no time go on.
Future<void> turn() => Future<void>.delayed(Duration.zero);

/// The state of a paywall as a scenario sees it.
final class Paywall {
  Paywall({
    required this.state,
    required this.states,
    required this.load,
    required this.select,
    required this.purchase,
    required this.restore,
    required this.openLink,
    required this.leave,
  });

  final PaywallState Function() state;
  final List<String> states;
  final Future<void> Function() load;
  final void Function(Plan plan) select;
  final Future<void> Function() purchase;
  final Future<void> Function() restore;
  final Future<void> Function(Uri url) openLink;
  final Future<void> Function() leave;
}

/// What the access of the user is as the widgets of the app see it.
final class Access {
  Access({required this.value, required this.leave});

  final AppAccess Function() value;
  final void Function() leave;
}
''';

/// What the paywall does in each scenario, whichever way the app manages
/// state: `paywallOf` creates its state over a controller of purchases,
/// with what opens a link.
const _scenarios = r'''
  // The plans load, and the yearly plan is selected.
  {
    final service = Scripted();
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    result['at first'] = show(paywall.state());
    await turn();
    await turn();
    result['loaded'] = show(paywall.state());
    paywall.select(monthly);
    result['selected'] = show(paywall.state());
    await turn();
    result['loaded: states'] = [...paywall.states];
    await paywall.leave();
  }

  // The plans do not load, and do on the next try.
  {
    final service = Scripted()
      ..plansFailure = const PurchasesFailure(
        PurchasesFailureReason.notConfigured,
        developerHint: 'A key is missing.',
      );
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    result['load failed'] = show(paywall.state());
    result['load failed: hint'] = paywall.state().loadFailure?.developerHint;
    service.plansFailure = null;
    await paywall.load();
    result['load again'] = show(paywall.state());
    await paywall.leave();
  }

  // A purchase gives premium access: the state stays busy while the user
  // has it, and is idle once it ends.
  {
    final service = Scripted();
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    paywall.states.clear();
    await paywall.purchase();
    await turn();
    result['bought'] = show(paywall.state());
    result['bought: calls'] = [...service.calls];
    service.tell(const NoAccess());
    await turn();
    await turn();
    result['access ended'] = show(paywall.state());
    result['bought: states'] = [...paywall.states];
    await paywall.leave();
  }

  // The user cancels the purchase.
  {
    final service = Scripted()..purchaseAnswer = null;
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    await paywall.purchase();
    await turn();
    result['cancelled'] = show(paywall.state());
    await paywall.leave();
  }

  // A purchase fails with each reason.
  for (final reason in PurchasesFailureReason.values) {
    final service = Scripted()
      ..failure = PurchasesFailure(reason, developerHint: 'why');
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    await paywall.purchase();
    await turn();
    result['failed ${reason.name}'] = show(paywall.state());
    await paywall.leave();
  }

  // A restore finds nothing, and then premium access.
  {
    final service = Scripted();
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    await paywall.restore();
    await turn();
    result['restored nothing'] = show(paywall.state());
    service.now = premium;
    await paywall.restore();
    await turn();
    result['restored premium'] = show(paywall.state());
    result['restore: calls'] = [...service.calls];
    await paywall.leave();
  }

  // A second call, and a selection, while a call is on its way.
  {
    final service = Scripted()..hold = Completer<void>();
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    final first = paywall.purchase();
    await turn();
    result['busy'] = show(paywall.state());
    final second = paywall.restore();
    paywall.select(monthly);
    await turn();
    result['busy: after more'] = show(paywall.state());
    service.hold!.complete();
    await first;
    await second;
    await turn();
    result['busy: calls'] = [...service.calls];
    await paywall.leave();
  }

  // The user leaves the paywall while a call is on its way, and the call
  // then fails or succeeds.
  for (final fails in [true, false]) {
    final name = fails ? 'left, then a failure' : 'left, then a success';
    final service = Scripted()..hold = Completer<void>();
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    final call = paywall.purchase();
    await turn();
    await paywall.leave();
    final told = paywall.states.length;
    if (fails) {
      service.failure = const PurchasesFailure(PurchasesFailureReason.network);
    }
    service.hold!.complete();
    try {
      await call;
      await turn();
      result['$name: error'] = null;
    } on Object catch (error) {
      result['$name: error'] = '$error';
    }
    result['$name: states told since'] = paywall.states.length - told;
  }

  // A restore while the plans did not load: the paywall still tells why
  // they did not, with what the restore found, and loads them on the next
  // try.
  {
    final service = Scripted()
      ..plansFailure = const PurchasesFailure(
        PurchasesFailureReason.notConfigured,
        developerHint: 'A key is missing.',
      );
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    await turn();
    service.hold = Completer<void>();
    final restore = paywall.restore();
    await turn();
    result['unavailable, restoring'] = show(paywall.state());
    service.hold!.complete();
    await restore;
    await turn();
    result['unavailable, restored nothing'] = show(paywall.state());
    result['unavailable, restored: hint'] =
        paywall.state().loadFailure?.developerHint;
    service.plansFailure = null;
    await paywall.load();
    result['unavailable, loaded again'] = show(paywall.state());
    await paywall.leave();
  }

  // A restore while the plans load does nothing, so that no plan comes in
  // to be bought while a restore is on its way.
  {
    final service = Scripted()..holdPlans = Completer<void>();
    final purchases = await purchasesOf(service);
    final paywall = paywallOf(purchases, []);
    await turn();
    final restore = paywall.restore();
    await turn();
    result['loading, restore'] = show(paywall.state());
    service.holdPlans!.complete();
    await restore;
    await turn();
    await turn();
    result['loading, then loaded'] = show(paywall.state());
    result['loading: calls'] = [...service.calls];
    await paywall.leave();
  }

  // A link opens with what the app gives the state.
  {
    final opened = <String>[];
    final purchases = await purchasesOf(Scripted());
    final paywall = paywallOf(purchases, opened);
    await paywall.openLink(Uri.parse('https://example.com/terms'));
    result['opened'] = opened;
    await paywall.leave();
  }

  // The access of the user for the widgets of the app follows the
  // purchases, and the screen of the subscription opens the page where the
  // user manages the plan.
  {
    final service = Scripted();
    final purchases = await purchasesOf(service);
    final access = accessOf(purchases);
    final seen = <String>[access.value().runtimeType.toString()];
    service.tell(premium);
    await turn();
    seen.add(access.value().runtimeType.toString());
    service.tell(const NoAccess());
    await turn();
    seen.add(access.value().runtimeType.toString());
    access.leave();
    result['access'] = seen;
    final opened = <String>[];
    await manage(purchases, opened, Uri.parse('https://example.com/manage'));
    result['managed'] = opened;
  }
''';

/// The functions with which the scenarios see the state of the variant for
/// bloc.
const _bloc = r'''
Paywall paywallOf(AppPurchasesController purchases, List<String> opened) {
  final cubit = PaywallCubit(purchases, (url) async => opened.add('$url'));
  final states = <String>[];
  cubit.stream.listen((state) => states.add(show(state)));
  return Paywall(
    state: () => cubit.state,
    states: states,
    load: cubit.load,
    select: cubit.select,
    purchase: cubit.purchase,
    restore: cubit.restore,
    openLink: cubit.openLink,
    leave: cubit.close,
  );
}

Access accessOf(AppPurchasesController purchases) {
  final cubit = PremiumCubit(purchases);
  return Access(value: () => cubit.state, leave: cubit.close);
}

Future<void> manage(
  AppPurchasesController purchases,
  List<String> opened,
  Uri url,
) async {
  final cubit = SubscriptionCubit(
    purchases,
    (url) async => opened.add('$url'),
  );
  await cubit.manage(url);
  await cubit.close();
}
''';

/// The functions with which the scenarios see the state of the variant for
/// riverpod.
const _riverpod = r'''
ProviderContainer containerOf(
  AppPurchasesController purchases,
  List<String> opened,
) => ProviderContainer(
  overrides: [
    appPurchasesProvider.overrideWithValue(purchases),
    paywallLinkOpenerProvider.overrideWithValue(
      (url) async => opened.add('$url'),
    ),
  ],
);

Paywall paywallOf(AppPurchasesController purchases, List<String> opened) {
  final container = containerOf(purchases, opened);
  final states = <String>[];
  final subscription = container.listen(
    paywallProvider,
    (_, next) => states.add(show(next)),
  );
  final notifier = container.read(paywallProvider.notifier);
  return Paywall(
    state: () => container.read(paywallProvider),
    states: states,
    load: notifier.load,
    select: notifier.select,
    purchase: notifier.purchase,
    restore: notifier.restore,
    openLink: notifier.openLink,
    leave: () async {
      subscription.close();
      container.dispose();
    },
  );
}

Access accessOf(AppPurchasesController purchases) {
  final container = containerOf(purchases, []);
  final subscription = container.listen(premiumProvider, (_, _) {});
  return Access(
    value: () => container.read(premiumProvider),
    leave: () {
      subscription.close();
      container.dispose();
    },
  );
}

Future<void> manage(
  AppPurchasesController purchases,
  List<String> opened,
  Uri url,
) async {
  final container = containerOf(purchases, opened);
  await container.read(paywallLinkOpenerProvider)(url);
  container.dispose();
}
''';

void main() {
  for (final variant in _variants) {
    final isBloc = variant.id == PaywallModule.blocVariant;

    group('the state of the paywall with ${variant.id}', () {
      late RenderedApp app;
      late Map<Object?, Object?> result;

      setUpAll(() async {
        app = await _rendered(variant.id);
        result = await runScript(
          app,
          imports: [
            'package:${variant.package}/${variant.package}.dart',
            _import(PurchasesRole.controllerFile),
            _import(PurchasesRole.serviceFile),
            _import(_state),
            for (final path in variant.stateFiles) _import(path),
          ],
          declarations: '$_prelude\n${isBloc ? _bloc : _riverpod}',
          body: _scenarios,
        );
      });

      test(
          'type-checks with the files of the purchases role, of the env '
          'role and the package that the state manager builds on', () async {
        expect(
          await analysisProblemsOf(app, [
            PurchasesRole.serviceFile,
            PurchasesRole.controllerFile,
            EnvRole.readerFile,
            'lib/${MemoryPurchasesModule.file}',
            _state,
            _texts,
            _links,
            _guards,
            ...variant.stateFiles,
          ]),
          isEmpty,
        );
      });

      test(
          'loads the plans once it is created, and selects the yearly plan '
          'whatever its place among them; a selection selects another '
          'plan', () {
        expect(result['at first'], 'loading');
        expect(result['loaded'], 'plans monthly yearly, selected yearly');
        expect(result['selected'], 'plans monthly yearly, selected monthly');
        expect(result['loaded: states'], [
          'plans monthly yearly, selected yearly',
          'plans monthly yearly, selected monthly',
        ]);
      });

      test(
          'tells why the plans did not load, with the hint of the provider, '
          'and loads them on the next try', () {
        expect(result['load failed'], 'load failed notConfigured');
        expect(result['load failed: hint'], 'A key is missing.');
        expect(result['load again'], 'plans monthly yearly, selected yearly');
      });

      test(
          'stays busy after a purchase for as long as the user has premium '
          'access, since the router closes the paywall, and is idle again '
          'once the access ends', () {
        expect(result['bought: calls'], ['plans', 'purchase yearly']);
        expect(
          result['bought'],
          'plans monthly yearly, selected yearly, busy purchase',
        );
        expect(result['access ended'], 'plans monthly yearly, selected yearly');
        expect(result['bought: states'], [
          'plans monthly yearly, selected yearly, busy purchase',
          'plans monthly yearly, selected yearly',
        ]);
      });

      test('is idle again, with nothing to tell, when the user cancels', () {
        expect(result['cancelled'], 'plans monthly yearly, selected yearly');
      });

      test(
          'tells of a failed purchase with its reason, and of a payment that '
          'waits for an approval with a notice', () {
        for (final reason in _reasons) {
          expect(
            result['failed $reason'],
            reason == 'pending'
                ? 'plans monthly yearly, selected yearly, notice pending'
                : 'plans monthly yearly, selected yearly, failed $reason',
            reason: reason,
          );
        }
      });

      test(
          'tells that a restore found nothing, and stays busy after one that '
          'found premium access', () {
        expect(
          result['restored nothing'],
          'plans monthly yearly, selected yearly, notice nothingToRestore',
        );
        expect(
          result['restored premium'],
          'plans monthly yearly, selected yearly, busy restore',
        );
        expect(result['restore: calls'], ['plans', 'restore', 'restore']);
      });

      test(
          'takes no second call and no selection while a call is on its '
          'way', () {
        expect(
          result['busy'],
          'plans monthly yearly, selected yearly, busy purchase',
        );
        expect(result['busy: after more'], result['busy']);
        expect(result['busy: calls'], ['plans', 'purchase yearly']);
      });

      test(
          'tells nothing once the user left the paywall, whatever the call '
          'that was on its way ends with', () {
        for (final name in ['left, then a failure', 'left, then a success']) {
          expect(result['$name: error'], isNull, reason: name);
          expect(result['$name: states told since'], 0, reason: name);
        }
      });

      test(
          'keeps why the plans did not load through a restore, which tells '
          'what it found, and loads them on the next try', () {
        expect(
          result['unavailable, restoring'],
          'load failed notConfigured, busy restore',
        );
        expect(
          result['unavailable, restored nothing'],
          'load failed notConfigured, notice nothingToRestore',
        );
        expect(result['unavailable, restored: hint'], 'A key is missing.');
        expect(
          result['unavailable, loaded again'],
          'plans monthly yearly, selected yearly',
        );
      });

      test(
          'takes no restore while the plans load, so that no plan is bought '
          'while a restore is on its way', () {
        expect(result['loading, restore'], 'loading');
        expect(
          result['loading, then loaded'],
          'plans monthly yearly, selected yearly',
        );
        expect(result['loading: calls'], ['plans']);
      });

      test('opens a link with what the app gives it', () {
        expect(result['opened'], ['https://example.com/terms']);
      });

      test(
          'gives the widgets of the app the access of the user, which '
          'follows the purchases, and opens the page of the store from the '
          'screen of the subscription', () {
        expect(result['access'], ['NoAccess', 'PremiumAccess', 'NoAccess']);
        expect(result['managed'], ['https://example.com/manage']);
      });
    });
  }

  group('what the paywall shows of a plan', () {
    late Map<Object?, Object?> result;

    setUpAll(() async {
      final app = await _rendered(PaywallModule.blocVariant);
      result = await runScript(
        app,
        imports: [
          'package:flutter/foundation.dart',
          'package:flutter/widgets.dart',
          'package:url_launcher/url_launcher.dart',
          _import(PurchasesRole.controllerFile),
          _import(_state),
          _import(_texts),
          _import(_links),
          _import(_guards),
        ],
        body: _plansScript,
      );
    });

    test(
        'names a term for the periods that the stores have, a week of 7 '
        'days and a year of 12 months among them, and none for another', () {
      expect(result['terms'], {
        '1 day': null,
        '7 day': 'week',
        '1 week': 'week',
        '2 week': null,
        '1 month': 'month',
        '2 month': 'twoMonths',
        '3 month': 'threeMonths',
        '4 month': null,
        '6 month': 'sixMonths',
        '12 month': 'year',
        '1 year': 'year',
        '2 year': null,
      });
    });

    test(
        'names the whole length of an intro offer, its period times its '
        'cycles, for the lengths of the free trials of the stores', () {
      expect(result['lengths'], {
        '3 day x1': 'threeDays',
        '7 day x1': 'oneWeek',
        '1 week x1': 'oneWeek',
        '1 week x2': 'twoWeeks',
        '14 day x1': 'twoWeeks',
        '1 month x1': 'oneMonth',
        '1 month x2': 'twoMonths',
        '1 month x3': 'threeMonths',
        '3 month x1': 'threeMonths',
        '6 month x1': 'sixMonths',
        '1 month x12': 'oneYear',
        '1 year x1': 'oneYear',
        '5 day x1': null,
        '3 week x1': null,
        '4 month x1': null,
        '2 year x1': null,
      });
    });

    test(
        'selects the first yearly plan, or else the first plan, and none of '
        'no plans', () {
      expect(result['preselected'], {
        'monthly yearly': 'yearly',
        'monthly lifetime': 'monthly',
        'yearly12 yearly': 'yearly12',
        '': null,
      });
    });

    test(
        'marks a yearly plan as the best value only when it costs less than '
        'twelve months of a monthly plan in the same currency', () {
      expect(result['best value'], {
        'cheaper yearly': true,
        'monthly itself': false,
        'dearer yearly': false,
        'other currency': false,
        'no monthly': false,
      });
    });

    test(
        'names each plan, its price with what follows it, and the label of '
        'the button by its plan', () {
      expect(result['names'], [
        'Weekly',
        'Monthly',
        'Every 2 months',
        'Every 3 months',
        'Every 6 months',
        'Yearly',
        'Lifetime',
        'Store title',
      ]);
      // With no-break spaces, so that a line never breaks inside a price.
      expect(result['prices'], [
        for (final price in [
          r'$1.99 / week',
          r'$4.99 / month',
          r'$8.99 / 2 months',
          r'$12.99 / 3 months',
          r'$19.99 / 6 months',
          r'$29.99 / year',
          r'$79.99 once',
          r'$3.99',
        ])
          _noBreak(price),
      ]);
      expect(result['labels'], [
        'Start free trial',
        'Subscribe',
        'Subscribe',
        'Buy',
        'Subscribe',
      ]);
    });

    test(
        'tells what an intro offer gives, by its length, and what the plan '
        'costs after it', () {
      expect(result['offers'], [
        '1 week free',
        '3 days free',
        'Free trial',
        r'$1.99 for 3 months',
        r'$0.99 / month for 3 months',
        'Introductory price',
        'Introductory price',
      ]);
      expect(result['after offers'], [
        '1 week free, then ${_noBreak(r'$29.99 / year')}',
        '\$0.99 / month for 3 months, then ${_noBreak(r'$4.99 / month')}',
        null,
      ]);
    });

    test(
        'tells the terms of the store of the platform, with what the user '
        'pays after an intro offer, and that a plan paid once is no '
        'subscription', () {
      final terms = result['terms of plans']! as Map<Object?, Object?>;
      const apple = 'The plan renews automatically until you cancel it. '
          'Payment is charged to your Apple Account. Cancel at least 24 '
          'hours before the period ends, in the settings of the App Store.';
      const google = 'The plan renews automatically until you cancel it. '
          'Cancel anytime in Google Play, under Payments & subscriptions.';
      const trial = 'Unless you cancel before the free trial ends, the full '
          'price is charged then.';
      const intro = 'After the introductory price, the full price is charged '
          'for each period.';
      expect(terms['android trial'], '$google $trial');
      expect(terms['android intro'], '$google $intro');
      expect(terms['android plain'], google);
      expect(terms['iOS plain'], apple);
      expect(terms['macOS plain'], apple);
      expect(terms['iOS lifetime'], 'One-time payment. No subscription.');
    });

    test('has a text for each reason of a failure and for each notice', () {
      expect(result['failures'], {
        'network': 'No connection. Check the internet and try again.',
        'pending': 'Your purchase is waiting for approval. Premium unlocks '
            'once it goes through.',
        'alreadyOwned': 'Your store account owns this plan already. Restore '
            'purchases to unlock premium.',
        'notAllowed': 'Purchases are not allowed on this device.',
        'unavailable': 'This plan is not available on this device.',
        'storeProblem': 'The store had a problem. Try again later.',
        'notConfigured': 'Purchases are unavailable right now.',
        'unknown': 'Something went wrong. Try again.',
      });
      expect(result['notices'], {
        'pending': 'Your purchase is waiting for approval. Premium unlocks '
            'once it goes through.',
        'nothingToRestore': 'No purchases to restore.',
      });
    });

    test(
        'takes a web address with https or http and a host, and nothing '
        'else, as a link', () {
      expect(result['addresses'], {
        'null': null,
        '': null,
        '   ': null,
        'example.com/terms': null,
        'mailto:legal@example.com': null,
        'ftp://example.com/terms': null,
        'https://': null,
        'https://example.com/terms': 'https://example.com/terms',
        ' http://example.com/privacy ': 'http://example.com/privacy',
        'https://example.com/terms#refunds':
            'https://example.com/terms#refunds',
      });
    });

    test(
        'links to the standard license agreement of Apple on iOS and macOS '
        'while .env has no terms of use, and to nothing elsewhere, names '
        'both keys as missing, and opens a link outside the app', () {
      expect(result['links'], {
        'android': [null, null],
        'iOS': [
          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
          null,
        ],
        'macOS': [
          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
          null,
        ],
      });
      expect(result['missing keys'], [
        PaywallModule.termsKey.name,
        PaywallModule.privacyKey.name,
      ]);
      expect(result['launched'], [
        'https://example.com/terms externalApplication',
      ]);
    });

    test('lets the guard read whether the user has premium access', () {
      expect(result['guard reads hasPremium'], isTrue);
    });
  });
}

/// What the script of the functions of the paywall finds, over plans and
/// offers of its own, in an app without the localization role.
const _plansScript = r'''
  const context = NoContext();
  Plan plan(String id, String price, BillingPeriod? period,
      {IntroOffer? offer, num amount = 1, String currency = 'USD'}) =>
      Plan(
        id: id,
        title: id == 'odd' ? 'Store title' : id,
        price: price,
        amount: amount,
        currencyCode: currency,
        period: period,
        introOffer: offer,
      );
  final units = {
    'day': BillingUnit.day,
    'week': BillingUnit.week,
    'month': BillingUnit.month,
    'year': BillingUnit.year,
  };
  BillingPeriod period(String text) {
    final [count, unit] = text.split(' ');
    return BillingPeriod(int.parse(count), units[unit]!);
  }

  result['terms'] = {
    for (final text in [
      '1 day', '7 day', '1 week', '2 week', '1 month', '2 month', '3 month',
      '4 month', '6 month', '12 month', '1 year', '2 year',
    ])
      text: termOf(period(text))?.name,
  };
  result['lengths'] = {
    for (final text in [
      '3 day x1', '7 day x1', '1 week x1', '1 week x2', '14 day x1',
      '1 month x1', '1 month x2', '1 month x3', '3 month x1', '6 month x1',
      '1 month x12', '1 year x1', '5 day x1', '3 week x1', '4 month x1',
      '2 year x1',
    ])
      text: lengthOf(
        IntroOffer(
          price: r'$0.00',
          amount: 0,
          period: period(text.split(' x').first),
          cycles: int.parse(text.split(' x').last),
        ),
      )?.name,
  };

  final yearly = plan('yearly', r'$29.99', period('1 year'), amount: 29.99);
  final yearly12 = plan('yearly12', r'$29.99', period('12 month'), amount: 29.99);
  final monthly = plan('monthly', r'$4.99', period('1 month'), amount: 4.99);
  final lifetime = plan('lifetime', r'$79.99', null, amount: 79.99);
  result['preselected'] = {
    'monthly yearly': preselectedPlan([monthly, yearly])?.id,
    'monthly lifetime': preselectedPlan([monthly, lifetime])?.id,
    'yearly12 yearly': preselectedPlan([yearly12, yearly])?.id,
    '': preselectedPlan(const [])?.id,
  };
  final dearer = plan('dearer', r'$69.99', period('1 year'), amount: 69.99);
  final euro = plan('euro', '29,99 €', period('1 year'), amount: 29.99,
      currency: 'EUR');
  result['best value'] = {
    'cheaper yearly': isBestValue(yearly, [monthly, yearly]),
    'monthly itself': isBestValue(monthly, [monthly, yearly]),
    'dearer yearly': isBestValue(dearer, [monthly, dearer]),
    'other currency': isBestValue(euro, [monthly, euro]),
    'no monthly': isBestValue(yearly, [yearly, lifetime]),
  };

  final plans = [
    plan('weekly', r'$1.99', period('1 week')),
    monthly,
    plan('two', r'$8.99', period('2 month')),
    plan('three', r'$12.99', period('3 month')),
    plan('six', r'$19.99', period('6 month')),
    yearly,
    lifetime,
    plan('odd', r'$3.99', period('5 week')),
  ];
  result['names'] = [for (final plan in plans) planNameOf(context, plan)];
  result['prices'] = [for (final plan in plans) priceOf(context, plan)];

  const freeWeek = IntroOffer(
    price: r'$0.00',
    amount: 0,
    period: BillingPeriod(1, BillingUnit.week),
  );
  const lowerMonths = IntroOffer(
    price: r'$0.99',
    amount: 0.99,
    period: BillingPeriod(1, BillingUnit.month),
    cycles: 3,
  );
  final offers = [
    freeWeek,
    const IntroOffer(
      price: r'$0.00',
      amount: 0,
      period: BillingPeriod(3, BillingUnit.day),
    ),
    const IntroOffer(
      price: r'$0.00',
      amount: 0,
      period: BillingPeriod(5, BillingUnit.day),
    ),
    const IntroOffer(
      price: r'$1.99',
      amount: 1.99,
      period: BillingPeriod(3, BillingUnit.month),
    ),
    lowerMonths,
    // A lower price of a length without words, and one of several periods
    // of a period without words.
    const IntroOffer(
      price: r'$0.99',
      amount: 0.99,
      period: BillingPeriod(5, BillingUnit.day),
    ),
    const IntroOffer(
      price: r'$0.10',
      amount: 0.1,
      period: BillingPeriod(1, BillingUnit.day),
      cycles: 3,
    ),
  ];
  result['offers'] = [for (final offer in offers) offerTextOf(context, offer)];
  final trialYearly = plan('yearly', r'$29.99', period('1 year'),
      offer: freeWeek, amount: 29.99);
  final introMonthly = plan('monthly', r'$4.99', period('1 month'),
      offer: lowerMonths, amount: 4.99);
  result['after offers'] = [
    afterOfferTextOf(context, trialYearly),
    afterOfferTextOf(context, introMonthly),
    afterOfferTextOf(context, monthly),
  ];
  result['labels'] = [
    purchaseLabelOf(context, trialYearly),
    purchaseLabelOf(context, introMonthly),
    purchaseLabelOf(context, monthly),
    purchaseLabelOf(context, lifetime),
    purchaseLabelOf(context, null),
  ];
  final terms = <String, String>{};
  defaultTargetPlatform = TargetPlatform.android;
  terms['android trial'] = termsTextOf(context, trialYearly);
  terms['android intro'] = termsTextOf(context, introMonthly);
  terms['android plain'] = termsTextOf(context, monthly);
  defaultTargetPlatform = TargetPlatform.iOS;
  terms['iOS plain'] = termsTextOf(context, monthly);
  terms['iOS lifetime'] = termsTextOf(context, lifetime);
  defaultTargetPlatform = TargetPlatform.macOS;
  terms['macOS plain'] = termsTextOf(context, monthly);
  result['terms of plans'] = terms;
  result['failures'] = {
    for (final reason in PurchasesFailureReason.values)
      reason.name: failureTextOf(context, reason),
  };
  result['notices'] = {
    for (final notice in PaywallNotice.values)
      notice.name: noticeTextOf(context, notice),
  };

  result['addresses'] = {
    for (final value in [
      null, '', '   ', 'example.com/terms', 'mailto:legal@example.com',
      'ftp://example.com/terms', 'https://', 'https://example.com/terms',
      ' http://example.com/privacy ', 'https://example.com/terms#refunds',
    ])
      '$value': webAddressOf(value)?.toString(),
  };
  final links = <String, List<String?>>{};
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    defaultTargetPlatform = platform;
    links[platform.name] = [
      paywallTermsUrl()?.toString(),
      paywallPrivacyUrl()?.toString(),
    ];
  }
  defaultTargetPlatform = TargetPlatform.android;
  result['links'] = links;
  result['missing keys'] = missingPaywallKeys();
  await openPaywallLink(Uri.parse('https://example.com/terms'));
  result['launched'] = launched;
  result['guard reads hasPremium'] =
      identical(paywallHasPremium(), appPurchases.hasPremium);
''';
