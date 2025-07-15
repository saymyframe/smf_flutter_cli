import 'package:smf_analytics/bundles/smf_firebase_analytics_brick_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

class FirebaseAnalyticsModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(
      name: 'firebase_analytics',
      bundle: smfFirebaseAnalyticsBrickBundle,
    ),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFirebaseAnalytics,
    description: 'Firebase Analytics module',
    dependsOn: {kFirebaseCore, kGetItModule},
    pubDependency: {'firebase_analytics: ^11.5.2'},
  );

  @override
  List<Contribution> get sharedFileContributions => [
    InsertImport(
      file: 'lib/features/home/home_screen.dart',
      import:
          "import 'package:{{app_name_sc}}/features/analytics/analytics_screen.dart';",
    ),
    InsertIntoListInMethodInClass(
      file: 'lib/features/home/home_screen.dart',
      className: 'HomeScreen',
      method: 'build',
      listVariableMatch: 'children',
      parentExpressionMatch: 'Column',
      index: 0,
      insert: '''
      TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AnalyticsScreen()),
        ),
        child: Text('Open analytics screen'),
      ),
      ''',
    ),
  ];

  @override
  List<DiDependencyGroup> get di => [
    DiDependencyGroup(
      diDependencies: [
        DiDependency(
          abstractType: 'IAnalyticsService',
          implementation:
              'FirebaseAnalyticsService(FirebaseAnalytics.instance)',
          bindingType: DiBindingType.singleton,
        ),
      ],
      scope: DiScope.core,
      imports: [
        DiImport.core(
          DiImportAnchor.coreService,
          'analytics/firebase/firebase_analytics_service.dart',
        ),
        DiImport.core(
          DiImportAnchor.coreService,
          'analytics/i_analytics_service.dart',
        ),
        DiImport.direct(
          "import 'package:firebase_analytics/firebase_analytics.dart';",
        ),
      ],
    ),
  ];
}
