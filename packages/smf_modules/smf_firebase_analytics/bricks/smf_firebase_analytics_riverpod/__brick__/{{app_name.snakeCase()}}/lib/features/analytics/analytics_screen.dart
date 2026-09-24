import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{app_name.snakeCase()}}/features/analytics/providers/analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Firebase analytics screen demo')),
      body: SafeArea(
        child: TextButton(
          onPressed: () {
            ref.read(analyticsServiceProvider).logEvent('test_event');
          },
          child: Text('Log analytics event'),
        ),
      ),
    );
  }
}
