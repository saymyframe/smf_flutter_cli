import 'package:flutter/material.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_card.dart';
import 'paywall_links.dart';
import 'paywall_state.dart';
import 'paywall_texts.dart';
import 'paywall_widgets.dart';

/// What the paywall shows: the card of premium access, what it gives, a
/// card for each plan of the current offer, the button that buys the
/// selected plan with what the plan costs after its intro offer and the
/// terms of the store, and the links that restore purchases and lead to the
/// terms of use and the privacy policy. Its close button is at the top,
/// outside what scrolls, whenever there is a page below to go back to.
///
/// It keeps nothing of the calls themselves: the screen gives it the state
/// of the paywall and takes what the user asks for. So it is the same
/// whichever way the app manages state. It never closes itself after a
/// purchase or a restore: the router closes it once the user has premium
/// access.
class PaywallView extends StatefulWidget {
  /// Creates the view.
  const PaywallView({
    required this.state,
    required this.onSelect,
    required this.onPurchase,
    required this.onRestore,
    required this.onRetry,
    required this.onOpenLink,
    super.key,
  });

  /// The state of the paywall.
  final PaywallState state;

  /// Selects a plan.
  final void Function(Plan plan) onSelect;

  /// Buys the selected plan.
  final VoidCallback onPurchase;

  /// Restores what the store account of the user bought.
  final VoidCallback onRestore;

  /// Loads the plans again, after they did not load.
  final VoidCallback onRetry;

  /// Opens a link of the paywall outside the app.
  final void Function(Uri url) onOpenLink;

  @override
  State<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<PaywallView>
    with TickerProviderStateMixin {
  /// Lets the parts of the paywall rise in one after another, once.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Lets the cards of the plans come in one after another once they are
  /// there.
  late final AnimationController _plansIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // An app that asks for less motion shows the paywall at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      _plansIn.value = 1;
    } else {
      // The entrance starts when the paywall is first built. A widget test
      // that starts the app in real time, as with tester.runAsync(), does
      // so once in its file: when a second test of the file starts the app
      // again, the time of this animation runs backwards, and Flutter
      // fails an assertion.
      _entrance.forward();
      if (widget.state.plans != null) _plansIn.value = 1;
    }
  }

  @override
  void didUpdateWidget(PaywallView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.plans == null && widget.state.plans != null) {
      // An app that asks for less motion shows the plans at once.
      if (MediaQuery.disableAnimationsOf(context)) {
        _plansIn.value = 1;
      } else {
        _plansIn.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _plansIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = widget.state;
    final idle = state.busy == null;
    final selected = state.selected;
    // Whether a page below this one is there to go back to.
    final canClose = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final failure = state.failure;
    final notice = state.notice;
    final terms = paywallTermsUrl();
    final privacy = paywallPrivacyUrl();
    final afterOffer = selected == null
        ? null
        : afterOfferTextOf(context, selected);
    final inset = MediaQuery.paddingOf(context).bottom;
    // On a phone with room for it, the button stays in sight at the bottom
    // while the rest scrolls. On a small phone, or with a large text size,
    // it scrolls with the rest, so that the plans have room.
    final pinned =
        MediaQuery.sizeOf(context).height >= 640 &&
        MediaQuery.textScalerOf(context).scale(16) <= 24;
    // What the last call ended with, such as a restore that found nothing.
    final message = PaywallMessage(
      text: failure != null
          ? failureTextOf(context, failure.reason)
          : notice != null
          ? noticeTextOf(context, notice)
          : null,
      failed: failure != null,
      hint: failure?.developerHint,
    );
    // What buys: the message, the button and what the selected plan costs
    // after its intro offer. While the plans did not load, there is nothing
    // to buy, and the message is above the links.
    final purchase = state.loadFailure != null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              message,
              PurchaseButton(
                label: purchaseLabelOf(context, selected),
                busy: state.busy == PaywallAction.purchase,
                onPressed: idle && selected != null ? widget.onPurchase : null,
              ),
              if (afterOffer != null) ...[
                const SizedBox(height: 10),
                WholeWords(
                  afterOffer,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          );
    // What the user agrees to, and the links.
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (purchase == null) message,
        if (selected != null && state.loadFailure == null) ...[
          WholeWords(
            termsTextOf(context, selected),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _Links(
          links: [
            // While the plans load, there is no restore either, so that no
            // plan comes in to be bought while one is on its way.
            PaywallLink(
              label: {{{text_restore}}},
              busy: state.busy == PaywallAction.restore,
              onPressed: idle && !state.loading ? widget.onRestore : null,
            ),
            if (terms != null)
              PaywallLink(
                label: {{{text_terms}}},
                onPressed: () => widget.onOpenLink(terms),
              ),
            if (privacy != null)
              PaywallLink(
                label: {{{text_privacy}}},
                onPressed: () => widget.onOpenLink(privacy),
              ),
          ],
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // The way out stays in sight on any phone, outside what
            // scrolls.
            SizedBox(
              height: 52,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: canClose
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: IconButton(
                          tooltip: {{{text_close}}},
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                // Without the button below it, the paywall scrolls under
                // what covers the bottom of the screen, such as the bar of
                // the home gesture, and ends above it.
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  pinned && purchase != null ? 24 : 32 + inset,
                ),
                child: _Phone(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Rise(
                        animation: _entrance,
                        order: 0,
                        child: PremiumCard(
                          animation: _entrance,
                          premium: {{{text_premium}}},
                        ),
                      ),
                      const SizedBox(height: 24),
                      Rise(
                        animation: _entrance,
                        order: 1,
                        child: _Benefits(
                          benefits: [
                            {{{text_benefit_all}}},
                            {{{text_benefit_new}}},
                            {{{text_benefit_support}}},
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Rise(
                        animation: _entrance,
                        order: 2,
                        child: _plansOf(context, state),
                      ),
                      const SizedBox(height: 16),
                      if (!pinned && purchase != null) ...[
                        Rise(animation: _entrance, order: 3, child: purchase),
                        const SizedBox(height: 12),
                      ],
                      Rise(animation: _entrance, order: 4, child: details),
                      DeveloperNote(
                        hint: state.loadFailure?.developerHint,
                        keys: missingPaywallKeys(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (pinned && purchase != null)
              Rise(
                animation: _entrance,
                order: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    // Above what covers the bottom of the screen.
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + inset),
                    child: _Phone(child: purchase),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The plans of [state]: grey cards while they load, a card for each of
  /// them, or what the paywall says when they did not load, with the button
  /// that loads them again.
  Widget _plansOf(BuildContext context, PaywallState state) {
    final plans = state.plans;
    final Widget shown;
    if (plans != null) {
      shown = Column(
        key: const ValueKey('plans'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, plan) in plans.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            Rise(
              animation: _plansIn,
              order: index,
              child: PlanCard(
                name: planNameOf(context, plan),
                price: plan.price,
                suffix: priceSuffixOf(context, plan.period),
                offer: switch (plan.introOffer) {
                  final offer? => offerTextOf(context, offer),
                  null => null,
                },
                badge: isBestValue(plan, plans) ? {{{text_best_value}}} : null,
                selected: plan == state.selected,
                onTap: state.busy == null ? () => widget.onSelect(plan) : null,
              ),
            ),
          ],
        ],
      );
    } else if (state.loadFailure != null) {
      shown = _Unavailable(
        key: const ValueKey('unavailable'),
        onRetry: widget.onRetry,
      );
    } else {
      shown = const Column(
        key: ValueKey('loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [PlanSkeleton(), SizedBox(height: 12), PlanSkeleton()],
      );
    }
    if (MediaQuery.disableAnimationsOf(context)) return shown;
    return AnimatedSwitcher(
      duration: Durations.medium2,
      // The plans that come in and the skeleton that leaves are as wide
      // as the paywall.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.passthrough,
        children: [...previous, ?current],
      ),
      child: shown,
    );
  }
}

/// [child] in the middle of the screen, no wider than a phone.
class _Phone extends StatelessWidget {
  const _Phone({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: child,
    ),
  );
}

/// What premium access gives, one line below the other, each with a check
/// in the accent of the theme of the app.
class _Benefits extends StatelessWidget {
  const _Benefits({required this.benefits});

  final List<String> benefits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, benefit) in benefits.indexed) ...[
          if (index > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              // With a large text size, a long word gets smaller rather
              // than break.
              Expanded(
                child: WholeWords(benefit, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// What the paywall shows in the place of the plans when they did not
/// load: that they are not available, and the button that loads them
/// again.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // As wide as the plans would be.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 32,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                {{{text_plans_unavailable}}},
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: WholeWords(
                {{{text_try_again}}},
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The links below the button of the paywall, side by side with a dot
/// between them, on more lines where they do not fit one.
class _Links extends StatelessWidget {
  const _Links({required this.links});

  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (index, link) in links.indexed) ...[
          if (index > 0)
            ExcludeSemantics(
              child: Text('·', style: TextStyle(color: colors.outline)),
            ),
          link,
        ],
      ],
    );
  }
}
