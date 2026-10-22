import 'package:flutter/material.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_card.dart';
import 'paywall_texts.dart';
import 'paywall_widgets.dart';

/// What the screen of the subscription shows to a user with premium access:
/// the card of premium access, unlocked, the plan, when it renews or ends,
/// or that it is for good, and the button to the page of the store where
/// the user manages the plan, when the store has one.
///
/// It keeps nothing of the access itself: the screen gives it the access of
/// the user and takes what the user asks for. So it is the same whichever
/// way the app manages state. When the access ends, the router closes the
/// screen; until then the view shows the access that the user had.
class SubscriptionView extends StatefulWidget {
  /// Creates the view.
  const SubscriptionView({
    required this.access,
    required this.onManage,
    super.key,
  });

  /// The access of the user.
  final AppAccess access;

  /// Opens the page of the store where the user manages the plan.
  final void Function(Uri url) onManage;

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView>
    with SingleTickerProviderStateMixin {
  /// Lets the parts of the screen rise in one after another, once.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  var _started = false;

  /// The access that the screen shows: that of the user, also once it
  /// ended, since the screen shows until the router closes it.
  late PremiumAccess? _shown = switch (widget.access) {
    final PremiumAccess access => access,
    NoAccess() => null,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // An app that asks for less motion shows the screen at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(SubscriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.access case final PremiumAccess access) _shown = access;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final access = _shown;
    // Whether a page below this one is there to go back to.
    final back = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final manageUrl = access?.manageUrl;
    return Scaffold(
      appBar: back ? AppBar() : null,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // The screen scrolls under what covers the bottom of the screen,
          // such as the bar of the home gesture, and ends above it.
          padding: EdgeInsets.fromLTRB(
            20,
            back ? 8 : 24,
            20,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Rise(
                    animation: _entrance,
                    order: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          // The title is large already, so it grows only by
                          // half with the text size of the device.
                          child: WholeWords(
                            {{{text_subscription_title}}},
                            style: theme.textTheme.headlineLarge,
                            maxScaleFactor: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          {{{text_subscription_intro}}},
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Rise(
                    animation: _entrance,
                    order: 1,
                    child: PremiumCard(
                      animation: _entrance,
                      premium: {{{text_premium}}},
                      badge: {{{text_unlocked}}},
                    ),
                  ),
                  if (access != null) ...[
                    const SizedBox(height: 24),
                    Rise(
                      animation: _entrance,
                      order: 2,
                      child: _Details(access: access),
                    ),
                  ],
                  if (manageUrl != null) ...[
                    const SizedBox(height: 24),
                    Rise(
                      animation: _entrance,
                      order: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => widget.onManage(manageUrl),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: WholeWords(
                              {{{text_manage}}},
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            {{{text_manage_hint}}},
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The plan of [access] and when it renews or ends, or that it is for
/// good, one below the other on a card, with a line between them.
class _Details extends StatelessWidget {
  const _Details({required this.access});

  final PremiumAccess access;

  @override
  Widget build(BuildContext context) {
    final period = access.period;
    final plan = period == null ? null : termNameOf(context, period);
    final expiresAt = access.expiresAt;
    final rows = [
      if (plan != null)
        _Row(
          icon: Icons.workspace_premium_outlined,
          label: {{{text_plan_label}}},
          value: plan,
        ),
      if (expiresAt == null)
        _Row(icon: Icons.all_inclusive_rounded, label: {{{text_lifetime_access}}})
      else
        _Row(
          icon: access.inTrial
              ? Icons.hourglass_bottom_rounded
              : access.renews
              ? Icons.autorenew_rounded
              : Icons.event_busy_outlined,
          label: access.inTrial
              ? {{{text_trial_ends_on}}}
              : access.renews
              ? {{{text_renews_on}}}
              : {{{text_ends_on}}},
          value: MaterialLocalizations.of(
            context,
          ).formatShortDate(expiresAt.toLocal()),
        ),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 56),
            row,
          ],
        ],
      ),
    );
  }
}

/// A row of the card of the subscription: its [icon], its [label] and its
/// [value], if it has one. A screen reader reads it as one line.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = this.value;
    return MergeSemantics(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        // Below the label, where a long value has the width of the row.
        subtitle: value == null
            ? null
            : Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
      ),
    );
  }
}
