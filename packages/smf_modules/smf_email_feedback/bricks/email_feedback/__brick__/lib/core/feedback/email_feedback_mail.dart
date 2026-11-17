/// The name of the app in the mail that a user writes to its developer: in
/// the subject, such as "Feedback: My App", and in the line about the app.
/// Change it here if you rename the app.
///
/// Unlike the name that the device shows, it is the same in every flavor,
/// so a filter of your mail finds every such mail by its subject.
const String emailFeedbackAppName = '{{app_name.titleCase()}}';

/// The flavor for a release, which users install from a store: the mail
/// names any other flavor, and not this one.
const String _releaseFlavor = '{{release_flavor}}';

/// What an email address may not have: a white space, and what a `mailto:`
/// link or a list of addresses would take apart.
const String _notInAddress = r'\s@?&#,;<>"()\\/:\[\]';

/// One email address, such as `support@example.com`: a name, an `@` and a
/// domain with a dot.
final RegExp _address = RegExp(
  '^[^$_notInAddress]+@[^$_notInAddress.]+(?:\\.[^$_notInAddress.]+)+\$',
);

/// Whether [value], without the spaces around it, is one email address,
/// such as `support@example.com`. Any other value, such as an empty one,
/// two addresses or an address with a query, counts as none.
bool isEmailFeedbackAddress(String? value) =>
    value != null && _address.hasMatch(value.trim());

/// The `mailto:` link of a new mail to [address], with [subject] and
/// [body], which the mail app of the device opens.
///
/// Each part is encoded as RFC 6068 asks: a space is `%20` and never `+`,
/// which a mail app would show as a plus, a line break is `%0D%0A`, and a
/// `+` of the address is `%2B`, which keeps the `@` as it is. So build such
/// a link here, and never with `Uri(queryParameters: ...)`, which writes a
/// space as `+`.
Uri emailFeedbackLink({
  required String address,
  required String subject,
  required String body,
}) {
  final trimmed = address.trim();
  final at = trimmed.lastIndexOf('@');
  final to = at < 0
      ? Uri.encodeComponent(trimmed)
      : '${Uri.encodeComponent(trimmed.substring(0, at))}@'
          '${Uri.encodeComponent(trimmed.substring(at + 1))}';
  return Uri.parse(
    'mailto:$to'
    '?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}

/// The line about the app in the mail, such as `My App 1.0.0 (1), dev`:
/// [emailFeedbackAppName], the [version] and the [buildNumber] of the app,
/// and the [flavor] of the build unless it is the flavor for a release,
/// which users install from a store. A part that is unknown or empty is
/// left out.
String emailFeedbackAppLine({
  String? version,
  String? buildNumber,
  String? flavor,
}) {
  final line = StringBuffer(emailFeedbackAppName);
  if (_known(version) case final version?) line.write(' $version');
  if (_known(buildNumber) case final build?) line.write(' ($build)');
  if (_known(flavor) case final flavor? when flavor != _releaseFlavor) {
    line.write(', $flavor');
  }
  return '$line';
}

/// The line about the device in the mail, such as
/// `Android 14 (SDK 34), Google Pixel 7` or `iOS 17.4, iPhone 15 Pro`: the
/// [system] with its [systemVersion] and, on Android, its [sdk], then the
/// [manufacturer] and the [model]. A model that starts with the name of its
/// manufacturer, whatever the case of its letters, does not repeat it. A
/// part that is unknown or empty is left out.
String emailFeedbackDeviceLine({
  String? system,
  String? systemVersion,
  int? sdk,
  String? manufacturer,
  String? model,
}) {
  final maker = _known(manufacturer);
  final name = _known(model);
  final systemPart = [
    ?_known(system),
    ?_known(systemVersion),
    ?(sdk == null ? null : '(SDK $sdk)'),
  ].join(' ');
  final repeats =
      maker != null &&
      name != null &&
      name.toLowerCase().startsWith(maker.toLowerCase());
  final devicePart = [?(repeats ? null : maker), ?name].join(' ');
  return [
    for (final part in [systemPart, devicePart])
      if (part.isNotEmpty) part,
  ].join(', ');
}

/// The body of the mail: two empty lines in which the user writes, then
/// [header], such as "About the app and the device:", and each of [lines]
/// that is not empty, with a line break of a mail, `\r\n`, between them.
String emailFeedbackBody({
  required String header,
  required List<String> lines,
}) =>
    [
      '',
      '',
      header,
      for (final line in lines)
        if (line.trim().isNotEmpty) line,
    ].join('\r\n');

/// [value] without the spaces around it, or `null` when that leaves
/// nothing.
String? _known(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
