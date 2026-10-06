/// The symbol of the app named [appName], which the first page of the
/// onboarding shows in its cell, as an element of the periodic table has
/// one: `Ma` for `my_app`.
///
/// [appName] is the name of the package of the app, in snake_case. The
/// symbol is the first letter of its first word in upper case, and then
/// the first letter of its second word in lower case. A name of one word
/// gives the second letter of that word instead, as `No` for `notes`, and a
/// name of one letter gives that letter alone.
String appSymbolOf(String appName) {
  final words = appName.split('_');
  final first = words.first;
  final rest = words.length > 1 ? words[1] : first.substring(1);
  final second = rest.isEmpty ? '' : rest[0];
  return '${first[0].toUpperCase()}${second.toLowerCase()}';
}
