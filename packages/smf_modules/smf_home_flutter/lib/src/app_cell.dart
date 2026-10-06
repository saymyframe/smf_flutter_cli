/// The symbol of the app [appName] in its cell on the start screen, as an
/// element of the periodic table has one: `Ma` for `my_app`.
///
/// [appName] is the name of the package of the app, in snake_case. The
/// symbol is the first letter of its first word in upper case, and then the
/// first letter of its second word in lower case, or the second letter of a
/// name of one word. A name of one letter gives that letter alone.
String appSymbolOf(String appName) {
  final words = appName.split('_');
  final first = words.first.runes;
  final next = words.length > 1 ? words[1].runes : first.skip(1);
  return String.fromCharCodes(first.take(1)).toUpperCase() +
      String.fromCharCodes(next.take(1)).toLowerCase();
}

/// The number in the cell of the app [appName] on the start screen, where
/// an element has its atomic number: how many letters and digits the name
/// has, 5 for `my_app`.
int appNumberOf(String appName) =>
    RegExp('[A-Za-z0-9]').allMatches(appName).length;
