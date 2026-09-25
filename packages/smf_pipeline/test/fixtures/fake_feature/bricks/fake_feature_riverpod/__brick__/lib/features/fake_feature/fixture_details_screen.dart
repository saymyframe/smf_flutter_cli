import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_feature_composition.dart';

/// The details of an item, with a counter in a notifier.
{{{smf_router__screen_annotations__fake_feature__fixture_details_screen}}}
class FixtureDetailsScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: () => ref.read(fixtureTapsProvider.notifier).tap(),
        child: Text('$id ${tab ?? ''} ${ref.watch(fixtureTapsProvider)}'),
      );
}
