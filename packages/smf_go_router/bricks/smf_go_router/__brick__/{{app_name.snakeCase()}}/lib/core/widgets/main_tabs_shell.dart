import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainTabsShell extends StatefulWidget {
  const MainTabsShell({super.key, required this.child});

  final Widget child;

  @override
  State<MainTabsShell> createState() => _MainTabsShellState();
}

class _MainTabsShellState extends State<MainTabsShell> {
  final _tabs = <_TabInfo>[
  {{=<% %>=}}
  {{#tabsWidget}}
  {{{.}}}
  {{/tabsWidget}}
  <%={{ }}=%>
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _tabs.indexWhere((t) => location.startsWith(t.path));
    return index >= 0 ? index : 0;
  }

  void _onTap(int index) {
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onTap,
        items: _tabs
            .map(
              (t) =>
                  BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
      ),
    );
  }
}

class _TabInfo {
  final String path;
  final String? label;
  final IconData icon;

  const _TabInfo({
    required this.path,
    required this.icon,
    this.label,
  });
}