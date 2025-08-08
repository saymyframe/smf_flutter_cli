import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name.snakeCase()}}/core/services/navigation/navigation.dart';

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
    context.navigateTo(
      NavigationTarget(routeName: _tabs[index].path),
      strategy: NavigationStrategy.pushReplacement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final isSelected = index == currentIndex;

            return IconButton(
              icon: Icon(
                tab.icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).iconTheme.color,
              ),
              onPressed: () => _onTap(index),
            );
          }),
        ),
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
