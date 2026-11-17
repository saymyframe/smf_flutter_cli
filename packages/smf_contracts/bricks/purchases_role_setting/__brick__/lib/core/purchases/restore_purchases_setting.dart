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
    final found = switch (_outcome) {
      null => null,
      _Outcome.premium => {{{text_active}}},
      _Outcome.nothing => {{{text_none}}},
      _Outcome.failed => {{{text_failed}}},
    };
    return ListTile(
      leading: const Icon(Icons.restore),
      // At a large text size the title and what the restore found wrap
      // between their words.
      title: _WholeWords({{{text_title}}}),
      // A screen reader reads what the restore found once it comes.
      subtitle: found == null
          ? null
          : Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WholeWords(found),
                  // The words of the provider are for the developer of the
                  // app, and break where they need to, as in an address.
                  if (_hint case final hint? when kDebugMode) Text(hint),
                ],
              ),
            ),
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

/// A text that keeps its words whole: it breaks between its words and never
/// inside one. A space, a tab or a line break parts two words, and a
/// no-break space keeps the two words around it together as one.
///
/// It grows with the text size of the device. Where its longest word would
/// still not fit the width that the text has, as on a narrow phone with a
/// large text size, the text is as large as that word allows.
class _WholeWords extends StatelessWidget {
  const _WholeWords(this.text);

  /// The text.
  final String text;

  @override
  Widget build(BuildContext context) {
    // The style in which a Text paints: that of the text around it, and
    // bold for a user who asks for bold text.
    var style = DefaultTextStyle.of(context).style;
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        );
        // The words of the text, between its white spaces, where a line may
        // break: every one but a no-break space, which keeps the words
        // around it together.
        final words = text.split(RegExp(r'[^\S\u00A0\u2007\u202F]+'));
        // How wide the longest word is in a font of [size].
        double widestAt(double size) {
          var widest = 0.0;
          for (final word in words) {
            painter
              ..text = TextSpan(
                text: word,
                style: style.copyWith(fontSize: size),
              )
              ..layout();
            if (painter.width > widest) widest = painter.width;
          }
          return widest;
        }

        // The size of a text of Flutter whose style gives none.
        var size = style.fontSize ?? 14;
        var widest = widestAt(size);
        // In a few steps: the text size of a device may grow a small font
        // by more than a large one.
        for (var step = 0; step < 4 && widest > room && room > 0; step++) {
          // A little smaller than the width allows, so that the rounding of
          // the layout breaks no word.
          size *= room / widest * 0.98;
          widest = widestAt(size);
        }
        painter.dispose();
        return Text(
          text,
          style: style.copyWith(fontSize: size),
          textScaler: scaler,
        );
      },
    );
  }
}
