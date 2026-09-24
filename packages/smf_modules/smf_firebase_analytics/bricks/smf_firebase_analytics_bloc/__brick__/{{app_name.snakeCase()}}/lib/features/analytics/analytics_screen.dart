import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:{{app_name.snakeCase()}}/features/analytics/cubit/firebase_analytics_cubit.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FirebaseAnalyticsCubit.create(),
      child: Scaffold(
        appBar: AppBar(title: Text('Firebase analytics screen demo')),
        body: SafeArea(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                context.read<FirebaseAnalyticsCubit>().logAnalyticsEvent(
                  'test_event',
                );
              },
              child: Text('Log analytics event'),
            ),
          ),
        ),
      ),
    );
  }
}
