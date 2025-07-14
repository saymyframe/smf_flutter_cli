import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:{{app_name.snakeCase()}}/features/home/bloc/home_bloc.dart';
{{#imports}}
{{{.}}}
{{/imports}}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc.create()..add(const HomeFetchEvent()),
      child: Scaffold(
        appBar: AppBar(title: Text('Demo Home Screen')),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) {
                    if (state is ConnectedModulesState) {
                      return Column(
                        children: [
                          Text('The list of connected SMF modules'),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 20,
                            runSpacing: 10,
                            children: List.generate(
                              state.modules.length,
                              (index) => Text(state.modules[index]),
                            ),
                          ),
                        ],
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),

              {{#widget}}
              {{{.}}}
              {{/widget}}
              ],
            ),
          ),
        ),
      ),
    );
  }
}
