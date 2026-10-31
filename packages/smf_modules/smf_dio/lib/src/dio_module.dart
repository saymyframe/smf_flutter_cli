import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dio/bundles/dio_bundle.dart';
import 'package:smf_dio/src/agents.dart';
import 'package:smf_dio/src/readme.dart';

/// The module that sends the requests of the app with dio, and so provides the
/// REST role.
///
/// The template of the role generates `appRest` and everything that it
/// guarantees: the address, the token, what repeats, the timeout and the log.
/// This module adds `dio` to the dependencies of the app and implements
/// `RestTransport` of the role in `lib/core/rest/dio_rest_transport.dart`, one
/// exchange on a `Dio`:
/// - it keeps one `Dio`, which keeps a connection open while requests follow
///   within seconds, and creates it at the first request, so an app that makes
///   none pays nothing. A new one comes only when `HttpOverrides` change, as in
///   a test with `RestTestServer`, since a `Dio` keeps the `HttpClient` that it
///   created, and the one before closes once its last exchange ended;
/// - it leaves out `content-encoding` and its `content-length` for `gzip`
///   alone, the coding that `HttpClient` of `dart:io` decodes;
/// - it sends a body as a `Uint8List`, since `Dio` writes any other list as the
///   text of its JSON;
/// - it follows no redirect and takes any status as a reply, which `appRest`
///   reads;
/// - it tells of a connection that failed or broke with `RestConnectionFailed`,
///   with the type of the error and not its text, which may quote the query.
///
/// `createDio()` of that file is where the developer of the app adds an
/// interceptor. The role has no use for interceptors of its own, since a second
/// provider keeps its guarantees without them.
///
/// The module adds the section [readmeHeading] to the README of the app, and a
/// note to the section of the role in the guide for coding agents.
final class DioModule extends SmfModule {
  /// Creates the module.
  const DioModule();

  /// The id of the module.
  static const id = ModuleId('dio');

  static const _file = ImportRef.app('core/rest/dio_rest_transport.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'REST API with dio',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(restRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(dioBundle),
        const PubspecContribution.hosted('dio', '^5.11.1'),
        restRole.data(
          const RoleImplementation(
            type: TypeRef('DioRestTransport', import: _file),
            create: FactoryRef('createDioRestTransport', import: _file),
          ),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          restRole.description,
          AgentNote(agentNote),
        ),
      ];
}
