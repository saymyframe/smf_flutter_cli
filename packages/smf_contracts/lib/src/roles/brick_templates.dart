import 'dart:convert';

import 'package:smf_contracts/core.dart';

/// The text files of the bricks among [contributions], by path, each with
/// the text of its template.
///
/// A module rule reads them from the contributions of a module that apply
/// in the app (see [ModuleRuleInput.contributions]), to check what the
/// module declares against the files that its bricks generate.
Map<String, String> textTemplatesOf(List<Contribution> contributions) => {
      for (final contribution in contributions)
        if (contribution is BrickContribution)
          for (final file in contribution.bundle.files)
            if (file.type == 'text')
              file.path.replaceAll(r'\', '/'): utf8.decode(
                base64.decode(file.data),
                allowMalformed: true,
              ),
    };
