import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// The brick [name] with the text files [files], each by its path in the
/// app.
MasonBundle _bundle(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );

/// A provider of the purchases role for the tests, which keeps the
/// purchases in memory, in plain Dart: `memoryOffer` is the offer, and
/// `memoryPurchases` what each user bought.
///
/// So the apps of the tests of the module have purchases without the
/// package of a provider of the role, and the module is tested with a
/// provider that it does not know.
final class MemoryPurchasesModule extends SmfModule {
  /// Creates the module.
  const MemoryPurchasesModule();

  /// The id of the module.
  static const id = ModuleId('memory_purchases');

  /// The path below `lib/` of the file of the service.
  static const file = 'core/purchases/memory_purchases_service.dart';

  static const _file = ImportRef.app(file);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Purchases in memory (test)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(purchasesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(_bundle('memory_purchases', {'lib/$file': _code})),
        purchasesRole.data(
          const RoleImplementation(
            type: TypeRef('MemoryPurchasesService', import: _file),
            create: FactoryRef('createMemoryPurchasesService', import: _file),
          ),
        ),
      ];

  static const _code = r'''
import 'dart:async';

import 'purchases_service.dart';

/// The plans of the offer: a yearly plan with a free week, a monthly plan,
/// and a plan paid once.
List<Plan> memoryOffer = const [
  Plan(
    id: 'yearly',
    title: 'Yearly',
    price: r'$29.99',
    amount: 29.99,
    currencyCode: 'USD',
    period: BillingPeriod(1, BillingUnit.year),
    introOffer: IntroOffer(
      price: r'$0.00',
      amount: 0,
      period: BillingPeriod(1, BillingUnit.week),
    ),
  ),
  Plan(
    id: 'monthly',
    title: 'Monthly',
    price: r'$4.99',
    amount: 4.99,
    currencyCode: 'USD',
    period: BillingPeriod(1, BillingUnit.month),
  ),
  Plan(
    id: 'lifetime',
    title: 'Lifetime',
    price: r'$79.99',
    amount: 79.99,
    currencyCode: 'USD',
  ),
];

/// What each user bought, by the id of the user, `null` for the user of
/// the device.
final Map<String?, AppAccess> memoryPurchases = {};

/// Opens the purchases kept in memory.
PurchasesService createMemoryPurchasesService() => MemoryPurchasesService();

/// Purchases in memory: a purchase gives premium access at once.
final class MemoryPurchasesService implements PurchasesService {
  final StreamController<AppAccess> _changes = StreamController.broadcast();

  String? _user;

  @override
  Future<void> identify(String? userId) async => _user = userId;

  @override
  Future<AppAccess> access() async =>
      memoryPurchases[_user] ?? const NoAccess();

  @override
  Stream<AppAccess> get accessChanges => _changes.stream;

  @override
  Future<List<Plan>> plans() async => memoryOffer;

  @override
  Future<AppAccess?> purchase(Plan plan) async {
    final access = PremiumAccess(
      renews: plan.period != null,
      period: plan.period,
      inTrial: plan.introOffer?.isFree ?? false,
    );
    memoryPurchases[_user] = access;
    return access;
  }

  @override
  Future<AppAccess> restore() => access();
}
''';
}
