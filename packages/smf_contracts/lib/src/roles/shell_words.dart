/// The characters of an argument that a POSIX shell takes as they are, in any
/// place of a word but the first of a command.
final RegExp _plainWord = RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$');

/// [argument] as one word of a POSIX shell: as it is, or in single quotes,
/// inside which the shell reads every character as it is but a single quote.
///
/// The roles that write a command for a developer or a server to run, such
/// as the commands of CI and the text that names the tool arguments of the
/// values of `.env`, quote its arguments with it.
String shellWord(String argument) => _plainWord.hasMatch(argument)
    ? argument
    : "'${argument.replaceAll("'", r"'\''")}'";
