import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_purchases.dart';

/// The entry of the settings screen that restores purchases: a tap gives
/// the user what the store account of the user bought, such as on a new
/// device, and the entry tells what it found.
///
/// While a restore is on its way, the entry shows a spinner and takes no
/// other tap. A failure shows its text, and in debug mode the words of the
/// provider below it.
class RestorePurchasesSetting extends StatefulWidget {
  /// Creates the setting.
  const RestorePurchasesSetting({super.key});

  @override
  State<RestorePurchasesSetting> createState() =>
      _RestorePurchasesSettingState();
}

/// What the last restore found.
enum _Outcome { premium, nothing, failed }

class _RestorePurchasesSettingState extends State<RestorePurchasesSetting> {
  bool _restoring = false;
  _Outcome? _outcome;
  String? _hint;

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _outcome = null;
      _hint = null;
    });
    _Outcome outcome;
    String? hint;
    try {
      final access = await appPurchases.restore();
      outcome = access is PremiumAccess ? _Outcome.premium : _Outcome.nothing;
    } on PurchasesFailure catch (failure) {
      outcome = _Outcome.failed;
      hint = failure.developerHint;
    }
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _outcome = outcome;
      _hint = hint;
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = switch (_outcome) {
      null => null,
      _Outcome.premium => {{{text_active}}},
      _Outcome.nothing => {{{text_none}}},
      _Outcome.failed => [
          {{{text_failed}}},
          // The words of the provider are for the developer of the app.
          if (_hint case final hint? when kDebugMode) hint,
        ].join('\n'),
    };
    return ListTile(
      leading: const Icon(Icons.restore),
      title: Text({{{text_title}}}),
      // A screen reader reads what the restore found once it comes.
      subtitle: message == null
          ? null
          : Semantics(liveRegion: true, child: Text(message)),
      trailing: _restoring
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _restore,
    );
  }
}
