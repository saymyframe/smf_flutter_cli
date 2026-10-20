import 'package:smf_contracts/smf_contracts.dart';

/// Whether [a] and [b] read the same in every language: the same English
/// text and the same translations, by the code of their language.
bool sameText(LocalizedText a, LocalizedText b) =>
    a.en == b.en &&
    a.translations.length == b.translations.length &&
    a.translations.entries.every(
      (translation) => b.translations[translation.key] == translation.value,
    );
