// A test of what only bottom_tabs does, which continuous integration runs
// in the apps of the fixture modules with bottom_tabs and both fixture
// features: the bar of its AppShell. The layout draws the bar itself, so
// the test checks what a bar of Flutter would bring along: a tab for each
// destination, what each tab says to a screen reader, a tap, the colour of
// the selected tab, the screen of a destination that fades in, less motion
// for a user who asks for it, and large text. It builds the AppShell of
// the app around destinations of its own, as the router does, and does not
// start the app, so it knows neither the router nor the features. The
// labels of the destinations of the app, in each of its languages, are
// checked in the running app by bottom_tabs_tap_test.dart next to it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';
import 'package:{{app_name}}/core/layout/destination.dart';

import 'bottom_tabs_bar.dart';

String _inbox(BuildContext context) => 'Inbox';
String _search(BuildContext context) => 'Search';
String _people(BuildContext context) => 'People';
String _long(BuildContext context) => 'A destination with a long label';

/// Three destinations, as the layout role gives them to a layout.
const _destinations = [
  Destination(label: _inbox, icon: Icons.inbox),
  Destination(label: _search, icon: Icons.search),
  Destination(label: _people, icon: Icons.people),
];

/// The labels of [_destinations], in their order.
const _labels = ['Inbox', 'Search', 'People'];

/// The least height of the bar, above the inset of the device.
const _barHeight = 64.0;

/// The key of the screen of the selected destination.
const _screenKey = ValueKey('screen');

/// What stands in for the router: it builds the AppShell with the
/// destination that was last selected, and notes each call of onSelect in
/// [selected].
class _Router extends StatefulWidget {
  const _Router({required this.destinations, required this.selected});

  final List<Destination> destinations;

  /// The indexes that onSelect was called with, in their order.
  final List<int> selected;

  @override
  State<_Router> createState() => _RouterState();
}

class _RouterState extends State<_Router> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => AppShell(
        destinations: widget.destinations,
        currentIndex: _index,
        onSelect: (index) {
          widget.selected.add(index);
          setState(() => _index = index);
        },
        // One widget for every destination, as the body that a router gives
        // the shell: it stays in the tree when the destination changes.
        body: _Screen(key: _screenKey, index: _index),
      );
}

/// The screen of the destination at [index], which counts in [created] the
/// times that it was put into the tree.
class _Screen extends StatefulWidget {
  const _Screen({required this.index, super.key});

  final int index;

  static int created = 0;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  @override
  void initState() {
    super.initState();
    _Screen.created++;
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('Screen ${widget.index}'));
}

/// Builds the main navigation of the layout around [destinations] in an
/// app of its own with [theme], for a user with the text size [textScale]
/// who asks for less motion if [lessMotion], and returns the indexes that
/// onSelect is called with from then on.
Future<List<int>> _pumpShell(
  WidgetTester tester, {
  List<Destination> destinations = _destinations,
  double textScale = 1,
  bool lessMotion = false,
  ThemeData? theme,
}) async {
  final selected = <int>[];
  _Screen.created = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: lessMotion,
        ),
        child: child!,
      ),
      home: _Router(destinations: destinations, selected: selected),
    ),
  );
  return selected;
}

/// The main navigation that the user sees.
AppShell _shell(WidgetTester tester) => tester.widget(find.byType(AppShell));

/// Selects the destination at [index] as the router does, with no tap, so
/// that nothing moves but what the layout moves.
Future<void> _select(WidgetTester tester, int index) async {
  _shell(tester).onSelect(index);
  await tester.pump();
}

/// The colours of the icon and of the label of each tab, in the order of
/// [_destinations].
List<(Color?, Color?)> _tabColors(WidgetTester tester) => [
      for (final (index, label) in _labels.indexed)
        (
          tester.widget<Icon>(tabIcon(tester, _destinations[index].icon)).color,
          tester.widget<Text>(tab(tester, label)).style?.color,
        ),
    ];

/// Where the icon and the label of each tab are, and how large, in the
/// order of [_destinations].
List<(Rect, Rect)> _tabRects(WidgetTester tester) => [
      for (final (index, label) in _labels.indexed)
        (
          tester.getRect(tabIcon(tester, _destinations[index].icon)),
          tester.getRect(tab(tester, label)),
        ),
    ];

/// The style of the label of each tab but for its colour, in the order of
/// [_destinations]. The font of a test gives a letter the same size
/// whatever its weight, so the place of a label does not tell its style.
List<TextStyle?> _labelStyles(WidgetTester tester) => [
      for (final label in _labels)
        tester
            .widget<Text>(tab(tester, label))
            .style
            ?.copyWith(color: const Color(0xFF000000)),
    ];

/// The colours of the theme of the main navigation.
ColorScheme _colors(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AppShell))).colorScheme;

/// How the layout shows the screen of the selected destination: how opaque,
/// and how far below its place.
(double, double) _screen(WidgetTester tester) => (
      tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(_screenKey),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      tester.getTopLeft(find.byKey(_screenKey)).dy,
    );

/// The screen of the selected destination as it is while nothing moves:
/// opaque, in its place.
const _shown = (1.0, 0.0);

/// The haptic feedback that the app asks the device for from now on, by
/// its names, in their order.
List<Object?> _haptics(WidgetTester tester) {
  final haptics = <Object?>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return haptics;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the bar has a tab for each destination, and is hidden with fewer than '
    'two',
    (tester) async {
      await _pumpShell(tester);
      final surface = tester.getSize(find.byType(MaterialApp));
      expect(
        [
          for (final (index, label) in _labels.indexed)
            (
              tab(tester, label).evaluate().length,
              tabIcon(tester, _destinations[index].icon).evaluate().length,
            ),
        ],
        everyElement((1, 1)),
        reason: 'The bar shows the label and the icon of each destination '
            'once.',
      );
      expect(
        [for (final label in _labels) tester.getCenter(tab(tester, label)).dx],
        [
          for (final sixths in [1, 3, 5])
            moreOrLessEquals(surface.width * sixths / 6),
        ],
        reason: 'The tabs share the width of the bar, in the order of the '
            'destinations.',
      );
      final barRect = tester.getRect(bar(tester));
      expect(
        (barRect.bottom, barRect.height),
        (surface.height, _barHeight),
        reason: 'The bar is at the bottom of the main navigation, and 64 '
            'high on a device without an inset there.',
      );
      expect(
        tester.getRect(find.byKey(_screenKey)).bottom,
        barRect.top,
        reason: 'The screen of the selected destination ends where the bar '
            'starts.',
      );

      await _pumpShell(tester, destinations: _destinations.sublist(0, 1));
      expect(
        barWidget(tester),
        isNull,
        reason: 'With one destination there is nothing to switch to, so the '
            'layout shows no bar.',
      );
      expect(
        [find.text('Inbox'), find.byIcon(Icons.inbox)],
        everyElement(findsNothing),
        reason: 'Without a bar, the layout shows no tab.',
      );
      expect(
        tester.getSize(find.byKey(_screenKey)),
        surface,
        reason: 'Without a bar, the screen of the destination fills the main '
            'navigation.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'each tab is one button for a screen reader, with the label of its '
    'destination, selected or not',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final selected = await _pumpShell(tester);

        /// Checks what the tabs say while the destination at [current] is
        /// selected.
        void expectTabs(int current) {
          for (final (index, label) in _labels.indexed) {
            // One node has the label, that of the tab: the finder fails on
            // a second one. The icon and the text of the tab are no nodes
            // of their own, so a screen reader reads the label once.
            final node = tester.getSemantics(find.bySemanticsLabel(label));
            expect(
              node,
              isSemantics(
                label: label,
                isButton: true,
                hasSelectedState: true,
                isSelected: index == current,
                hasTapAction: true,
              ),
              reason: 'The tab of $label is a button with that label, which '
                  'a screen reader can tap, and it says whether it is '
                  'selected.',
            );
            expect(
              node.childrenCount,
              0,
              reason: 'The tab of $label is one node for a screen reader.',
            );
          }
        }

        expectTabs(0);

        // A screen reader selects a tab with the tap action of its node.
        tester.semantics.tap(find.semantics.byLabel('People'));
        await tester.pumpAndSettle();
        expect(
          selected,
          [2],
          reason: 'The tap action of a tab selects its destination.',
        );
        expectTabs(2);
      } finally {
        semantics.dispose();
      }
    },
    timeout: timeout,
  );

  testWidgets(
    'a tap on a tab selects its destination, with a tick of the device when '
    'it is another one',
    (tester) async {
      final haptics = _haptics(tester);
      final selected = await _pumpShell(tester);

      await tester.tap(tab(tester, 'Search'));
      await tester.pumpAndSettle();
      expect(
        selected,
        [1],
        reason: 'A tap on a tab calls onSelect with the index of its '
            'destination.',
      );
      expect(
        haptics,
        ['HapticFeedbackType.selectionClick'],
        reason: 'A tap on the tab of another destination asks the device '
            'for the tick of a selection.',
      );

      // The icon is a part of the tab too. What a tap on the selected tab
      // does is up to the router, so the layout passes it on.
      await tester.tap(tabIcon(tester, Icons.search));
      await tester.pumpAndSettle();
      expect(
        selected,
        [1, 1],
        reason: 'A tap on the selected tab calls onSelect too.',
      );
      expect(
        haptics,
        ['HapticFeedbackType.selectionClick'],
        reason: 'A tap on the selected tab asks the device for no tick.',
      );

      // Where the tab has neither its icon nor its label: at its left edge
      // and just below its top.
      final barRect = tester.getRect(bar(tester));
      await tester.tapAt(barRect.topLeft + const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(
        selected,
        [1, 1, 0],
        reason: 'The whole of a tab takes a tap, not only its icon and its '
            'label.',
      );

      // Flutter paints the ink of a tap on the nearest Material above the
      // tab, below what that Material has around the tab. The bar is that
      // Material, so the ink shows on the bar and ends at its edges.
      final materials = find.descendant(
        of: bar(tester),
        matching: find.byType(Material),
        matchRoot: true,
      );
      expect(
        [for (final material in materials.evaluate()) material.size],
        [tester.getSize(bar(tester))],
        reason: 'The bar is one Material, on which the ink of a tap on a tab '
            'shows.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the selected tab takes the accent colour over time and keeps its size',
    (tester) async {
      await _pumpShell(tester);
      final colors = _colors(tester);
      final accent = (colors.secondary, colors.secondary);
      final plain = (colors.onSurfaceVariant, colors.onSurfaceVariant);
      expect(
        accent,
        isNot(plain),
        reason: 'The theme of the test tells the selected tab from the '
            'others.',
      );
      expect(
        _tabColors(tester),
        [accent, plain, plain],
        reason: 'The icon and the label of the selected tab are in the '
            'secondary colour of the theme, and those of the others in its '
            'onSurfaceVariant colour.',
      );
      final rects = _tabRects(tester);

      await _select(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _tabColors(tester),
        [
          isNot(anyOf(accent, plain)),
          isNot(anyOf(accent, plain)),
          plain,
        ],
        reason: 'The tab that is selected takes the accent colour over '
            'time, and the tab that was selected loses it.',
      );
      expect(
        _tabRects(tester),
        rects,
        reason: 'A tab changes neither its size nor its place while it '
            'becomes the selected one.',
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _tabColors(tester),
        [plain, accent, plain],
        reason: 'The tabs have their colours within half a second.',
      );
      expect(
        _tabRects(tester),
        rects,
        reason: 'The selected tab is as large as the others, and where it '
            'was.',
      );
      expect(
        _labelStyles(tester).toSet(),
        hasLength(1),
        reason: 'The label of the selected tab differs from the others in '
            'its colour alone.',
      );
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'Once the tabs have their colours, nothing moves: the app '
            'settles.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the screen of a destination fades in and rises once when the '
    'destination changes',
    (tester) async {
      await _pumpShell(tester);
      expect(
        _screen(tester),
        _shown,
        reason: 'The first screen is shown at once, in its place.',
      );

      await _select(tester, 1);
      expect(find.text('Screen 1'), findsOneWidget);
      expect(
        _screen(tester),
        (0.0, 10.0),
        reason: 'The screen of another destination starts transparent, a '
            'little below its place.',
      );
      await tester.pump(const Duration(milliseconds: 100));
      final (opacity, drop) = _screen(tester);
      expect(
        [opacity, drop / 10],
        everyElement(allOf(greaterThan(0), lessThan(1))),
        reason: 'The screen fades in while it rises to its place.',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _screen(tester),
        _shown,
        reason: 'The screen is opaque, in its place, within half a second.',
      );
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'Once the screen is in its place, nothing moves: the app '
            'settles.',
      );
      expect(
        _Screen.created,
        1,
        reason: 'The layout keeps the body that the router gives it in the '
            'tree, with its state, when the destination changes.',
      );

      await _select(tester, 1);
      expect(
        _screen(tester),
        _shown,
        reason: 'The screen of the selected destination does not fade in '
            'again when its destination is selected again.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'for a user who asks for less motion, the tab and the screen change at '
    'once',
    (tester) async {
      await _pumpShell(tester, lessMotion: true);
      final colors = _colors(tester);
      final accent = (colors.secondary, colors.secondary);
      final plain = (colors.onSurfaceVariant, colors.onSurfaceVariant);

      await _select(tester, 1);
      expect(
        _tabColors(tester),
        [plain, accent, plain],
        reason: 'With less motion, the tabs have their colours in the frame '
            'that follows the selection.',
      );
      expect(find.text('Screen 1'), findsOneWidget);
      expect(
        _screen(tester),
        _shown,
        reason: 'With less motion, the screen of another destination is '
            'shown at once, in its place.',
      );
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'With less motion, the layout moves nothing when the '
            'destination changes.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'large text fits the bar, and a long press on a tab shows its label',
    (tester) async {
      // A small phone, five destinations and text at three times its size.
      const phone = Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = phone;
      addTearDown(tester.view.reset);
      const destinations = [
        ..._destinations,
        Destination(label: _long, icon: Icons.star),
        Destination(label: _long, icon: Icons.settings),
      ];
      final selected = await _pumpShell(
        tester,
        destinations: destinations,
        textScale: 3,
      );
      // An overflow is an error of Flutter, which fails the test.
      expect(
        tester.getSize(bar(tester)).height,
        _barHeight,
        reason: 'The bar is 64 high while its labels fit.',
      );
      final labels = tester
          .elementList(
            find.descendant(of: bar(tester), matching: find.byType(Text)),
          )
          .toList();
      expect(labels, hasLength(destinations.length));
      final tabWidth = phone.width / destinations.length;
      for (final (index, label) in labels.indexed) {
        final rect = tester.getRect(find.byWidget(label.widget));
        expect(
          (rect.left >= index * tabWidth, rect.right <= (index + 1) * tabWidth),
          (true, true),
          reason: 'The label of a tab stays inside the tab, cut short if it '
              'is too long: the label of the tab $index is at $rect.',
        );
        expect(
          MediaQuery.textScalerOf(label).scale(10),
          13,
          reason: 'The bar shows a label at most 1.3 times its size.',
        );
      }

      // What the bar cuts short or keeps small, a long press shows in
      // full, above the bar, at the text size of the device.
      await tester.longPress(tab(tester, 'Inbox'));
      await tester.pump();
      final barRect = tester.getRect(bar(tester));
      final tooltips = [
        for (final text in find.text('Inbox').evaluate())
          if (tester.getRect(find.byWidget(text.widget)).bottom <= barRect.top)
            text,
      ];
      expect(
        tooltips,
        hasLength(1),
        reason: 'A long press on a tab shows its label in a tooltip above '
            'the bar.',
      );
      expect(
        MediaQuery.textScalerOf(tooltips.single).scale(10),
        30,
        reason: 'The tooltip of a tab follows the text size of the device.',
      );
      expect(
        selected,
        isEmpty,
        reason: 'A long press on a tab selects nothing.',
      );
      // The tooltip goes away after a while, with no tap.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        find.text('Inbox'),
        findsOneWidget,
        reason: 'The tooltip of a tab goes away after a while.',
      );

      // With labels that are taller than the bar, here from the theme, the
      // bar grows rather than cutting them.
      await _pumpShell(
        tester,
        destinations: destinations,
        textScale: 3,
        theme: ThemeData(
          textTheme: const TextTheme(labelMedium: TextStyle(fontSize: 40)),
        ),
      );
      // The app takes a new theme over time.
      await tester.pumpAndSettle();
      final grown = tester.getRect(bar(tester));
      expect(
        (grown.height > _barHeight, grown.bottom),
        (true, phone.height),
        reason: 'The bar grows upwards with labels that 64 are too low for: '
            'it is at $grown.',
      );
    },
    timeout: timeout,
  );
}
