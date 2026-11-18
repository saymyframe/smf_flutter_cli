// ignore: deprecated_member_use
import 'package:flutter/material.dart';{{#with_note}}
import 'package:flutter/services.dart';

/// The path of this file in the app, which the screen names for the
/// developer of the app.
const _file = 'lib/features/settings/settings_screen.dart';{{/with_note}}

{{#with_entries}}/// The settings of the app: an entry for each setting that a module of the
/// app has, one below the other in one group.{{#with_conditions}} An entry with a condition
/// shows only while the condition holds{{#with_note}}, and while none holds, the screen
/// says that the app has no settings yet and tells the developer of the app
/// where a setting goes{{/with_note}}.{{/with_conditions}}{{/with_entries}}{{^with_entries}}/// The settings of the app, which has none yet: no module of the app has a
/// setting, so the screen says so and tells the developer of the app where
/// a setting goes.{{/with_entries}}
///
/// As a destination of the main navigation, the screen has no app bar.
/// Shown on top of another screen, it has one, for the back button.
{{{smf_router__screen_annotations__settings__settings_screen}}}
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        header: true,
        // A title that is too long for its line, as with a large text
        // size, gets smaller rather than break inside a word.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            {{{text_title}}},
            style: theme.textTheme.headlineLarge,
          ),
        ),
      ),
    );
    // Whether a screen below this one is there to go back to.
    final back = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;{{#with_entries}}{{#with_note}}
    // The entries that show, in their order: each only while its condition
    // holds, which the screen asks each time it builds.
    final entries = <Widget>[{{/with_note}}{{/with_entries}}
{{{shown_entries}}}
{{#with_entries}}{{#with_note}}    ];
{{/with_note}}{{/with_entries}}    return Scaffold(
      appBar: back ? AppBar() : null,
      body: SafeArea(
        bottom: false,
        child: {{#with_entries}}{{#with_note}}entries.isEmpty
            ? {{/with_note}}{{/with_entries}}{{#with_note}}LayoutBuilder(
          // The note in the middle of the rest of the screen, and below
          // the title on a screen too small for both, where the two
          // scroll. The column is at least as tall as the screen, and as
          // tall as the layout of the note needs, whose texts wrap within
          // a width of their own.
          builder: (context, screen) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: screen.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: title,
                  ),
                  const _NoSettings(),
                  // As much room below the note as above it.
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ){{/with_note}}{{#with_entries}}{{#with_note}}
            : {{/with_note}}ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            title,
            const SizedBox(height: 20),
            {{^with_conditions}}const {{/with_conditions}}_Group(
              children: {{#with_note}}entries,{{/with_note}}{{^with_note}}[{{/with_note}}{{/with_entries}}
{{{entries}}}
{{#with_entries}}{{^with_note}}              ],
{{/with_note}}            ),
          ],
        ){{/with_entries}},
      ),
    );
  }
}{{#with_entries}}

/// The group of the entries of the screen: its [children] one below the
/// other on a card, with a line between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Divider(height: 1, indent: 56),
          child,
        ],
      ],
    ),
  );
}{{/with_entries}}{{#with_note}}

{{#with_entries}}/// What the screen shows while none of its entries shows: that the app has
/// no settings yet, and the file in which its developer adds one. It comes
/// in once. The first entry that shows takes its place.{{/with_entries}}{{^with_entries}}/// What the screen shows while no module of the app has a setting: that
/// the app has none yet, and the file in which its developer adds one. It
/// comes in once. The first setting of the app takes its place.{{/with_entries}}
class _NoSettings extends StatelessWidget {
  const _NoSettings();

  /// Copies the path of this file and says so.
  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: _file));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied: $_file')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // An app that is asked for less motion shows the note at once.
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Durations.long2,
      curve: Easing.emphasizedDecelerate,
      builder: (context, shown, child) => Opacity(
        opacity: shown,
        child: Transform.translate(
          offset: Offset(0, (1 - shown) * 16),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 168,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Smaller cells around the cell of the screen.
                    for (final (alignment, size, color, outlined) in [
                      (
                        const Alignment(-1, -0.7),
                        36.0,
                        colors.secondaryContainer,
                        false,
                      ),
                      (const Alignment(1, -1), 26.0, colors.outline, true),
                      (
                        const Alignment(0.9, 0.9),
                        30.0,
                        colors.tertiaryContainer,
                        false,
                      ),
                    ])
                      Align(
                        alignment: alignment,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: outlined ? null : color,
                            border: outlined ? Border.all(color: color) : null,
                          ),
                        ),
                      ),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        border: Border.all(color: colors.onSurface, width: 1.5),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 44,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'No settings yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  'A module with a setting adds its entry here. You can add '
                  'your own in this file.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                child: Material(
                  color: colors.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _copy(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            // The path wraps where it does not fit. At a
                            // large text size it grows only by half, so
                            // that it breaks at its slashes and not inside
                            // a name.
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.5,
                              child: Text(
                                _file,
                                // The monospaced font of the device.
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontFamilyFallback: const [
                                    'Menlo',
                                    'Courier',
                                  ],
                                  fontSize: 12,
                                  letterSpacing: 0,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}{{/with_note}}
