// Writes the URL scheme of Google of each iOS app that firebase.json names
// into ios/Runner/Info.plist, which all the flavors share. The Google Sign-In
// SDK stops an iOS app whose Info.plist lacks the scheme of its client. The
// scheme is REVERSED_CLIENT_ID of the GoogleService-Info.plist of the app,
// which has it once Google is enabled in its Firebase project.
//
// tool/configure_firebase.dart runs this script after every run of
// flutterfire, and tool/enable_firebase_sign_in.dart after it downloaded the
// Firebase files again. After `flutterfire configure` by hand, run it
// yourself:
//
//     dart tool/firebase_configured/write_google_url_schemes.dart
//
// It adds a scheme and removes none, and leaves a file that has them all as
// it is. It stops at an Info.plist in a form that it does not know, with what
// to add there by hand.

import 'dart:convert';
import 'dart:io';

/// The file of the app with the URL schemes of the iOS app.
const _infoPlist = 'ios/Runner/Info.plist';

/// The script of the app that enables Google in the Firebase project.
const _enableSignIn = 'dart tool/enable_firebase_sign_in.dart';

void main() {
  // The app is the directory above `tool`, wherever the script is run from.
  final script = File.fromUri(Platform.script).resolveSymbolicLinksSync();
  final app = File(script).parent.parent.parent;
  try {
    final schemes = _schemesOf(app);
    if (schemes.isNotEmpty) _writeUrlSchemes(app, schemes);
  } on _Stop catch (stop) {
    stderr.writeln(stop.why);
    exitCode = 1;
  }
}

/// Why the script stops without writing the URL schemes.
final class _Stop implements Exception {
  const _Stop(this.why);

  final String why;
}

/// The text of [file], which is in UTF-8.
String _textOf(File file) {
  try {
    return file.readAsStringSync();
  } on FileSystemException catch (error) {
    throw _Stop(
      '${file.path} could not be read as a text in UTF-8 (${error.message}).',
    );
  }
}

/// [items] as a sentence lists them, such as `A, B and C`.
String _listed(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

/// The URL schemes of the clients of Google of the iOS apps of [app], each
/// once: `REVERSED_CLIENT_ID` of the Firebase file of each iOS app that
/// `firebase.json` names, wherever flutterfire writes it there, for each
/// build configuration and target. It tells of a file that is missing, and
/// of one that has no client of Google yet, with the command that enables
/// Google in its project, and of a `firebase.json` that names no iOS app.
///
/// Throws a [_Stop] when `firebase.json` is not JSON.
List<String> _schemesOf(Directory app) {
  final config = File('${app.path}/firebase.json');
  if (!config.existsSync()) {
    stdout.writeln(
      'firebase.json is missing, so no flavor of the app is configured for '
      'Firebase yet, and no URL scheme of Google is written.',
    );
    return const [];
  }
  final Object? json;
  try {
    json = jsonDecode(_textOf(config));
  } on FormatException catch (error) {
    throw _Stop(
      'firebase.json is not JSON (${error.message}), so no URL scheme of '
      'Google is written.',
    );
  }
  // The Firebase file of each iOS app, with the project of the app, which
  // flutterfire writes next to it.
  final files = <String, String?>{};
  void collect(Object? node) {
    if (node is! Map) return;
    if (node['fileOutput'] case final String file) {
      final project = node['projectId'];
      files.putIfAbsent(file, () => project is String ? project : null);
    }
    for (final value in node.values) {
      collect(value);
    }
  }

  // The projects of all the flavors: with several, the script that enables
  // Google needs the project of a run.
  final projects = <String>{};
  void projectsIn(Object? node) {
    if (node is! Map) return;
    if (node['projectId'] case final String project) projects.add(project);
    for (final value in node.values) {
      projectsIn(value);
    }
  }

  if (json case {'flutter': final Object? flutter}) projectsIn(flutter);
  if (json case {'flutter': {'platforms': {'ios': final Object? ios}}}) {
    collect(ios);
  }
  if (files.isEmpty) {
    stdout.writeln(
      'firebase.json names no iOS app, so no URL scheme of Google is written.',
    );
  }
  final schemes = <String>{};
  for (final MapEntry(key: path, value: project) in files.entries) {
    final file = File('${app.path}/$path');
    if (!file.existsSync()) {
      stdout.writeln(
        '$path, which firebase.json names, is missing, so no URL scheme of '
        'Google is written for it.',
      );
      continue;
    }
    final scheme = RegExp(
      r'<key>REVERSED_CLIENT_ID</key>\s*<string>([A-Za-z0-9.-]+)</string>',
    ).firstMatch(_textOf(file))?[1];
    if (scheme == null) {
      final command = project != null && projects.length > 1
          ? '$_enableSignIn --project $project'
          : _enableSignIn;
      stdout.writeln(
        '$path${project == null ? '' : ', of the Firebase project $project,'} '
        'has no client of Google yet, as in a project in which Google is not '
        'enabled, so no URL scheme is written for it: $command enables Google '
        'there and writes it.',
      );
    } else {
      schemes.add(scheme);
    }
  }
  return schemes.toList();
}

/// Writes [schemes] into the URL schemes of [_infoPlist] of [app], those
/// that it does not have as the Google Sign-In SDK reads them
/// ([_urlSchemesIn]), as a URL type of their own, and leaves the file as it
/// is when it has them all.
///
/// Throws a [_Stop] with what to add by hand when the file is not in a form
/// that the script knows, and when it cannot be read or written.
void _writeUrlSchemes(Directory app, List<String> schemes) {
  final file = File('${app.path}/$_infoPlist');
  if (!file.existsSync()) {
    throw _Stop(
      '$_infoPlist is missing, so this script cannot write the URL scheme '
      'of Google, ${_listed(schemes)}, into it.',
    );
  }
  final String text;
  try {
    text = file.readAsStringSync();
  } on FileSystemException catch (error) {
    throw _Stop('$_infoPlist could not be read (${error.message}).');
  }
  // In lower case, as the Google Sign-In SDK compares them.
  final present = _urlSchemesIn(text);
  final missing = [
    for (final scheme in schemes)
      if (present.add(scheme.toLowerCase())) scheme,
  ];
  if (missing.isEmpty) {
    stdout.writeln('$_infoPlist has the URL scheme of Google already.');
    return;
  }
  stdout.writeln(
    'Writing the URL scheme of Google, ${_listed(missing)}, into '
    '$_infoPlist.',
  );
  final changed = _withUrlSchemes(text, missing);
  final newline = text.contains('\r\n') ? '\r\n' : '\n';
  if (changed == null) {
    throw _Stop(
      '$_infoPlist is not in a form in which this script can add the URL '
      'scheme. Add this to CFBundleURLTypes there by hand:\n'
      '${_urlTypesOf(missing, '', newline).trimRight()}',
    );
  }
  try {
    file.writeAsStringSync(changed);
  } on FileSystemException catch (error) {
    throw _Stop(
      '$_infoPlist could not be written (${error.message}). Add this to '
      'CFBundleURLTypes there by hand:\n'
      '${_urlTypesOf(missing, '', newline).trimRight()}',
    );
  }
}

/// The URL schemes of the app in [text], an Info.plist in XML, in lower
/// case, as the Google Sign-In SDK reads them (`-signInWithOptions:` of
/// `GIDSignIn.m` in GoogleSignIn-iOS 9): the strings of the
/// `CFBundleURLSchemes` of each item of `CFBundleURLTypes`. A scheme under
/// another key, such as `LSApplicationQueriesSchemes`, or in a comment is
/// none of them.
Set<String> _urlSchemesIn(String text) {
  final plain = text.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final types = RegExp(
    r'<key>CFBundleURLTypes</key>\s*(?=<array>)',
  ).firstMatch(plain);
  final schemes = <String>{};
  if (types == null) return schemes;
  // The URL types end where their array ends, after the arrays within it.
  var depth = 0;
  for (final tag in RegExp(r'<(/?)array>').allMatches(plain, types.end)) {
    depth += tag[1]!.isEmpty ? 1 : -1;
    if (depth > 0) continue;
    final of = RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).allMatches(plain.substring(types.end, tag.start));
    for (final array in of) {
      for (final scheme in RegExp(
        '<string>([^<]*)</string>',
      ).allMatches(array[1]!)) {
        schemes.add(scheme[1]!.toLowerCase());
      }
    }
    break;
  }
  return schemes;
}

/// The URL types of [schemes] as the items of `CFBundleURLTypes`, each line
/// after [indent], one tab further in for each level, and ending with
/// [newline].
String _urlTypesOf(List<String> schemes, String indent, String newline) => [
  for (final scheme in schemes) ...[
    '$indent<dict>',
    '$indent\t<key>CFBundleTypeRole</key>',
    '$indent\t<string>Editor</string>',
    '$indent\t<key>CFBundleURLSchemes</key>',
    '$indent\t<array>',
    '$indent\t\t<string>$scheme</string>',
    '$indent\t</array>',
    '$indent</dict>',
  ],
].map((line) => '$line$newline').join();

/// [text], an Info.plist in XML, with the URL types of [schemes] added: at
/// the end of `CFBundleURLTypes`, or in a `CFBundleURLTypes` of their own
/// at the end of the dictionary of the file. Returns `null` when [text] is
/// not in a form that the script knows.
String? _withUrlSchemes(String text, List<String> schemes) {
  final newline = text.contains('\r\n') ? '\r\n' : '\n';
  // The start of the line of the tag at [index], when only spaces and tabs
  // come before it there.
  int? lineOf(int index) {
    final start = text.lastIndexOf('\n', index - 1) + 1;
    return text.substring(start, index).trim().isEmpty ? start : null;
  }

  String insert(int at, String lines) =>
      '${text.substring(0, at)}$lines${text.substring(at)}';
  final key = RegExp(r'<key>CFBundleURLTypes</key>\s*');
  final keys = key.allMatches(text).toList();
  if (keys.length > 1) return null;
  if (keys case [final found]) {
    if (text.startsWith('<array/>', found.end)) {
      final line = lineOf(found.start);
      if (line == null) return null;
      final indent = text.substring(line, found.start);
      return text.replaceRange(
        found.end,
        found.end + '<array/>'.length,
        '<array>$newline${_urlTypesOf(schemes, '$indent\t', newline)}'
        '$indent</array>',
      );
    }
    if (!text.startsWith('<array>', found.end)) return null;
    // The end of that array, after the arrays within it.
    var depth = 0;
    for (final tag in RegExp(r'<(/?)array>').allMatches(text, found.end)) {
      depth += tag[1]!.isEmpty ? 1 : -1;
      if (depth > 0) continue;
      final line = lineOf(tag.start);
      if (line == null) return null;
      final indent = text.substring(line, tag.start);
      return insert(line, _urlTypesOf(schemes, '$indent\t', newline));
    }
    return null;
  }
  // The dictionary of the file ends with its last `</dict>`, right before
  // `</plist>`.
  final end = RegExp(r'</dict>\s*</plist>\s*$').firstMatch(text);
  final line = end == null ? null : lineOf(end.start);
  if (end == null || line == null) return null;
  final indent = '${text.substring(line, end.start)}\t';
  return insert(
    line,
    '$indent<key>CFBundleURLTypes</key>$newline'
    '$indent<array>$newline'
    '${_urlTypesOf(schemes, '$indent\t', newline)}'
    '$indent</array>$newline',
  );
}
