import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The path of this file, which the screen names.
const _file = 'lib/core/app/fallback_start_screen.dart';

/// The monospaced font of the device, for a path and a number.
const _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
);

/// The screen the app starts on when no route of the app can start it: the
/// [FallbackStartView] with its texts.
class FallbackStartScreen extends StatelessWidget {
  /// Creates the screen.
  const FallbackStartScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      {{^has_localization}}const {{/has_localization}}FallbackStartView(
        hint: {{{text_fallback_hint}}},
        copied: {{{text_fallback_copied}}},
      );
}

/// What the [FallbackStartScreen] shows: the name of the app, and where its
/// developer puts its first screen.
///
/// It takes its texts, so a test shows it with texts of its own.
class FallbackStartView extends StatelessWidget {
  /// Creates the view with its texts.
  const FallbackStartView({
    required this.hint,
    required this.copied,
    super.key,
  });

  /// Tells the developer of the app that it has no start screen yet.
  final String hint;

  /// What the view says before the path of this file once a tap copied it.
  final String copied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          // An app that asks for less motion shows the screen at once.
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A picture, which a screen reader passes over.
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 196,
                      height: 156,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Smaller cells around the cell of the app.
                          for (final (alignment, size, color, outlined) in [
                            (
                              const Alignment(-1, -0.7),
                              40.0,
                              colors.secondaryContainer,
                              false,
                            ),
                            (
                              const Alignment(1, -1),
                              28.0,
                              colors.outline,
                              true,
                            ),
                            (
                              const Alignment(0.9, 0.9),
                              34.0,
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
                                  border: outlined
                                      ? Border.all(color: color)
                                      : null,
                                ),
                              ),
                            ),
                          // The letters are part of the picture, so
                          // they keep their size with a larger text.
                          MediaQuery.withNoTextScaling(
                            child: Container(
                              width: 116,
                              height: 116,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLowest,
                                border: Border.all(
                                  color: colors.onSurface,
                                  width: 1.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 7,
                                    right: 10,
                                    child: Text(
                                      '{{app_number}}',
                                      style: _mono.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      '{{app_symbol}}',
                                      style: theme.textTheme.displayMedium
                                          ?.copyWith(
                                            fontSize: 54,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: -2,
                                            color: colors.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: Text(
                      '{{app_name.titleCase()}}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      hint,
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
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            const ClipboardData(text: _file),
                          );
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(content: Text('$copied: $_file')),
                            );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                // A path grows less than other text, so
                                // that it breaks at its slashes.
                                child: MediaQuery.withClampedTextScaling(
                                  maxScaleFactor: 1.5,
                                  child: Text(
                                    _file,
                                    style: _mono.copyWith(
                                      fontSize: 12,
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
        ),
      ),
    );
  }
}
