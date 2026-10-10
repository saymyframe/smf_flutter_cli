/// What the test that CI runs against its Firebase project knows of the
/// sign-in methods of a project: how the project answers a client that
/// signs in, what the Firebase CLI prints when it enables them, and why a
/// run that enables them fails. Nothing here reaches Firebase, so the tests
/// of this file run everywhere.
library;

import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';

/// The page of the Firebase console with the sign-in methods of [project].
String signInMethodsOf(String project) =>
    'https://console.firebase.google.com/project/$project/authentication/'
    'providers';

/// The API keys in [options], the text of `lib/firebase_options.dart` of an
/// app: that of each platform that flutterfire configured, and none in the
/// placeholder of an app that it has not configured yet.
List<String> apiKeysOf(String options) => [
      for (final key in RegExp("apiKey: '([^']+)'").allMatches(options))
        key[1]!,
    ];

/// How the test asks the project as a client, with the API key of the app:
/// a sign-in with a password, for an address that has no account, at this
/// address of the Identity Toolkit API, which Firebase Authentication
/// answers on. The request creates nothing, since it only signs in.
final Uri signInWithPassword = Uri.https(
  'identitytoolkit.googleapis.com',
  '/v1/accounts:signInWithPassword',
);

/// The codes with which a project with Email/Password answers a sign-in
/// for an address that has no account: the first one, unless the project
/// is without the protection against the enumeration of email addresses.
const enabledAnswers = {'INVALID_LOGIN_CREDENTIALS', 'EMAIL_NOT_FOUND'};

/// Who enables the sign-in methods in the Firebase project [project] of CI,
/// for a run that finds them not enabled.
String _whoEnables(String project) =>
    'Only one job of the workflow Build enables the sign-in methods in the '
    'project, with SMF_FIREBASE_ENABLE_SIGN_IN=1, so that two runs never '
    'write to it at once. Run Build first, such as by hand on this branch, '
    'or enable Email/Password at ${signInMethodsOf(project)}';

/// Why [status] and [body], the answer of the Firebase project [project] to
/// [signInWithPassword] for an address that has no account, do not show
/// that Email/Password is enabled in the project; `null` if they show it.
///
/// A project with Email/Password answers that the address or the password
/// is wrong ([enabledAnswers]). One in which Authentication is set up
/// without Email/Password answers `PASSWORD_LOGIN_DISABLED`, and one in
/// which Authentication was never set up `CONFIGURATION_NOT_FOUND`. Any
/// other answer tells nothing of the sign-in methods, such as one about the
/// API key of the app.
String? emailPasswordProblem({
  required String project,
  required int status,
  required String body,
}) {
  final message = _errorOf(body);
  final code = RegExp('^[A-Z_]+').stringMatch(message) ?? '';
  if (status == 400 && enabledAnswers.contains(code)) return null;
  return switch (code) {
    'PASSWORD_LOGIN_DISABLED' ||
    'OPERATION_NOT_ALLOWED' when status == 400 =>
      'The Firebase project $project answers a sign-in with a password with '
          '$code: Authentication is set up there, but Email/Password is not '
          'enabled, so nobody can sign in to the app. ${_whoEnables(project)}',
    'CONFIGURATION_NOT_FOUND' when status == 400 =>
      'The Firebase project $project answers a sign-in with a password with '
          '$code: Authentication was never set up there, so no way to sign '
          'in is enabled. ${_whoEnables(project)}',
    _ => 'The Firebase project $project answers a sign-in with a password, '
        'for an address without an account, with HTTP $status'
        '${message.isEmpty ? '' : ' ($message)'}, which does not tell '
        'whether Email/Password is enabled there. A project with it answers '
        '${enabledAnswers.join(' or ')}, one without it '
        'PASSWORD_LOGIN_DISABLED, and one in which Authentication was never '
        'set up CONFIGURATION_NOT_FOUND. An answer about the API key means '
        'that the app is not configured for this project, or that the key '
        'is restricted to its app.',
  };
}

/// The message of the error in [body], the JSON with which the Identity
/// Toolkit API answers a request that it refuses, or an empty text when
/// [body] is no such answer.
String _errorOf(String body) {
  try {
    return switch (jsonDecode(body)) {
      {'error': {'message': final String message}} => message,
      _ => '',
    };
  } on FormatException {
    return '';
  }
}

/// The app ids of the web apps in [listed], what
/// `firebase apps:list WEB --project=<project> --json` prints. The Firebase
/// CLI may print other lines before the JSON.
List<String> webAppIdsOf(String listed) {
  final json = jsonDecode(listed.substring(listed.indexOf('{')));
  final apps = (json as Map<String, Object?>)['result']! as List<Object?>;
  return [
    for (final app in apps.cast<Map<String, Object?>>()) '${app['appId']}',
  ];
}

/// Why a run may not enable the sign-in methods in the Firebase project
/// [project], whose web apps are [webApps], with the Firebase CLI; `null`
/// if it may.
///
/// The Firebase CLI enables the methods through a web app of the project,
/// and adds one, named "Default Web App", to a project that has none. That
/// registers an app in the project, which only a run that may [register]
/// does, of the workflow Build, as for the Android and iOS apps of CI.
String? webAppProblem({
  required List<String> webApps,
  required String project,
  required bool register,
}) =>
    webApps.isEmpty && !register
        ? 'The Firebase project $project has no web app, and the Firebase CLI '
            'would add one, named "Default Web App", to enable the sign-in '
            'methods through it. Only the runs of the workflow Build register '
            'an app in the project, with SMF_FIREBASE_REGISTER=1. Run Build '
            'first, such as by hand on this branch.'
        : null;

/// The line with which the Firebase CLI says that it enabled the sign-in
/// methods of an app in [mode]: it names Anonymous before Email/Password,
/// whatever the order of its configuration (`lib/deploy/auth/deploy.js` of
/// firebase-tools 15.14.0).
String enabledLineOf(AuthMode mode) {
  final methods = [
    if (mode == AuthMode.anonymous) 'anonymous',
    'email/password',
  ];
  return 'Auth providers enabled: ${methods.join(', ')}';
}

/// The permissions that `firebase deploy --only auth` is known to ask of
/// its account, for a failure in which the Firebase CLI names none.
///
/// The first is for the request that sets up the web app through which the
/// Firebase CLI enables the methods: Google enables the APIs of Firebase in
/// the project for it, and asks for the permission also where an API is
/// enabled already. The others are the one that every command asks and
/// those of the command (`TARGET_PERMISSIONS` in `lib/commands/deploy.js`
/// of firebase-tools 15.14.0).
const deployPermissions = [
  'serviceusage.services.enable',
  'firebase.projects.get',
  'firebase.projects.update',
  'firebaseauth.configs.update',
];

const _serviceUsageAdmin =
    'Service Usage Admin (roles/serviceusage.serviceUsageAdmin)';
const _firebaseAdmin = 'Firebase Admin (roles/firebase.admin)';

/// A role of Google Cloud that has every permission whose name starts with
/// the key, by the permissions that the reference of the IAM roles lists
/// for the role:
/// https://docs.cloud.google.com/iam/docs/roles-permissions/serviceusage
/// https://docs.cloud.google.com/iam/docs/roles-permissions/firebase
///
/// Firebase Admin has `serviceusage.services.get` and
/// `serviceusage.services.list` there, and not
/// `serviceusage.services.enable`. The test names no role for a permission
/// that is not here.
const Map<String, String> rolesWith = {
  'serviceusage.services.': _serviceUsageAdmin,
  'firebase.': _firebaseAdmin,
  'firebaseauth.': _firebaseAdmin,
  'firebasehosting.': _firebaseAdmin,
};

/// Whether [output], what a run of the script printed that failed, tells
/// that the project refused the Firebase CLI for lack of a permission.
///
/// firebase-tools 15.14.0 only notes the permissions that its own check
/// finds missing, in its debug output (`lib/requirePermissions.js`), and
/// fails later, when Google refuses the request that sets up the web app
/// of the project, with `Failed to provision Firebase app` and either the
/// HTTP error 403 or the permission that Google denied. A version that
/// stops at the check prints `Authorization failed`.
bool lacksPermission(String output) =>
    !apiIsDisabled(output) &&
    (missingPermissionsIn(output).isNotEmpty ||
        RegExp(
          'HTTP Error: 403|PERMISSION_DENIED|does not have permission|'
          'Permission denied|Authorization failed|required permissions',
        ).hasMatch(output));

/// Whether [output] tells that an API which the Firebase CLI calls is not
/// enabled in the project, which Google answers with the error 403 too.
bool apiIsDisabled(String output) => RegExp(
      'SERVICE_DISABLED|has not been used in project|API is not enabled',
    ).hasMatch(output);

/// The permissions that [output], what the Firebase CLI printed, says its
/// account lacks in the project, each once and in the order in which the
/// output names them; none if it names none.
///
/// Google names a permission that it denied as `permission: '<name>'`, in
/// the details of its answer, which the Firebase CLI prints with its
/// error. The permissions that the check of the Firebase CLI itself finds
/// missing are only in its output with `--debug`: the lines after
/// `missing the following required permissions`.
List<String> missingPermissionsIn(String output) {
  final lines = const LineSplitter().convert(output);
  final start = lines.indexWhere(
    (line) => line.contains('missing the following required permissions'),
  );
  final listed = RegExp(r'^\s+[a-z][A-Za-z.]+$');
  return {
    for (final denied
        in RegExp(r"permission: '([A-Za-z][\w.]*)'").allMatches(output))
      denied[1]!,
    if (start >= 0)
      for (final line in lines
          .skip(start + 1)
          .skipWhile((line) => line.trim().isEmpty)
          .takeWhile(listed.hasMatch))
        line.trim(),
  }.toList();
}

/// Whether a second run of the script, with `--debug`, may tell which
/// permission the account of the Firebase CLI lacks: [output], what the
/// script printed without it, tells of a lack of a permission and names
/// none.
bool debugMayNamePermission(String output) =>
    lacksPermission(output) && missingPermissionsIn(output).isEmpty;

/// What the test tells when the script of the app did not enable the
/// sign-in methods in the Firebase project [project]: it exited with
/// [code] and printed [output], and [debugOutput] in a second run with
/// `--debug`, if the test made one (see [debugMayNamePermission]).
///
/// It tells a lack of a permission from an API that is not enabled, from
/// credentials that the Firebase CLI did not take, and from every other
/// failure, each with what to do, before what the script printed. For a
/// lack of a permission, it names the permissions that [output] says the
/// account lacks, or else those of [debugOutput], or else
/// [deployPermissions], and a role for each that [rolesWith] has one for.
String enablingFailure({
  required String project,
  required int code,
  required String output,
  String debugOutput = '',
}) {
  final named = missingPermissionsIn(output);
  final missing = named.isEmpty ? missingPermissionsIn(debugOutput) : named;
  final why = switch (output) {
    _ when apiIsDisabled(output) =>
      'An API that the Firebase CLI calls is not enabled in the project. '
          'What it printed has the address at which the API is enabled.',
    _ when lacksPermission(output) =>
      'The project refused the Firebase CLI for lack of a permission'
          '${_whatToGrant(missing, project)}',
    _
        when RegExp(
          'Failed to authenticate|Could not load the default credentials|'
          'invalid_grant|Authentication Error',
        ).hasMatch(output) =>
      'The Firebase CLI did not take the key of the service account of CI, '
          'which the test gives it as GOOGLE_APPLICATION_CREDENTIALS.',
    _ => 'It is none of the failures that the test knows: a lack of a '
        'permission, an API that is not enabled, or credentials that the '
        'Firebase CLI did not take.',
  };
  return 'The script of the app did not enable the sign-in methods in the '
      'Firebase project $project (exit code $code). $why\n\n$output';
}

/// The rest of the sentence about a lack of a permission in [project]:
/// what the service account of CI lacks, and what to grant it where.
/// [missing] are the permissions that the Firebase CLI named. Where it
/// named none, the text lists [deployPermissions] instead.
String _whatToGrant(List<String> missing, String project) {
  final at =
      'at https://console.cloud.google.com/iam-admin/iam?project=$project';
  if (missing.isEmpty) {
    return ', and the Firebase CLI did not print which one. firebase deploy '
        '--only auth is known to ask for ${deployPermissions.join(', ')}. '
        'Grant the service account of CI a role for each of them that it '
        'lacks${_suchAs(deployPermissions)} $at';
  }
  final roles = _rolesFor(missing);
  final role = switch (missing) {
    [_] => 'a role that has it',
    _ when roles.values.firstOrNull?.length == missing.length =>
      'a role that has them',
    _ => 'roles that have them',
  };
  return '. The Firebase CLI printed what the service account of CI lacks: '
      '${missing.join(', ')}. Grant the service account '
      '$role${_suchAs(missing)} $at';
}

/// The roles of [rolesWith] for [permissions], each with those of
/// [permissions] that it has, in the order of [permissions]. A permission
/// that [rolesWith] has no role for is with none.
Map<String, List<String>> _rolesFor(List<String> permissions) {
  final roles = <String, List<String>>{};
  for (final permission in permissions) {
    for (final MapEntry(key: prefix, value: role) in rolesWith.entries) {
      if (permission.startsWith(prefix)) {
        roles.putIfAbsent(role, () => []).add(permission);
      }
    }
  }
  return roles;
}

/// The roles to name for [permissions] after "such as", between commas, or
/// nothing where [rolesWith] has a role for none of them. A role that has
/// them all stands alone, and any other with the permissions that it has.
String _suchAs(List<String> permissions) {
  final roles = _rolesFor(permissions);
  if (roles.isEmpty) return '';
  if (roles.values.first.length == permissions.length) {
    return ', such as ${roles.keys.first},';
  }
  return ', such as ${[
    for (final MapEntry(key: role, value: has) in roles.entries)
      '$role for ${has.join(', ')}',
  ].join(' and ')},';
}
