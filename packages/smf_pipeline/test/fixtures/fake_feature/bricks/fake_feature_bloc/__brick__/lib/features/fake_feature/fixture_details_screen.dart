import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'fake_feature_composition.dart';

/// The details of an item, with a counter in a cubit.
{{{smf_router__screen_annotations__fake_feature__fixture_details_screen}}}
class FixtureDetailsScreen extends StatelessWidget {
  /// Creates the screen of the item [id], on the tab [tab].
  const FixtureDetailsScreen({
    {{{smf_router__param_annotations__fake_feature__fixture_details_screen__id}}}
    required this.id,
    {{{smf_router__param_annotations__fake_feature__fixture_details_screen__tab}}}
    this.tab,
    super.key,
  });

  /// The item.
  final int id;

  /// The tab, if any.
  final String? tab;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => createFixtureCubit(),
        child: BlocBuilder<FixtureCubit, int>(
          builder: (context, taps) => TextButton(
            onPressed: () => context.read<FixtureCubit>().tap(),
            child: Text('$id ${tab ?? ''} $taps'),
          ),
        ),
      );
}
