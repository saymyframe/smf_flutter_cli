import 'package:smf_contracts/core.dart';

/// Whether [owner], who generated a file, is [contributor], who
/// contributed data: the same module, whichever of its variants, or the
/// template of the same role.
bool isContributor(
  ContributionOrigin owner,
  ContributionOrigin? contributor,
) =>
    switch ((owner, contributor)) {
      (ModuleOrigin(:final module), ModuleOrigin(module: final other)) =>
        module == other,
      _ => owner == contributor,
    };
