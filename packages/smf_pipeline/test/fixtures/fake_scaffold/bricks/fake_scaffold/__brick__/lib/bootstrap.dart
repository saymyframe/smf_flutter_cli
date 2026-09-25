{{{smf_app_entry__top_level}}}

/// Runs the start-up code of all modules before the app starts.
Future<void> bootstrap() async {
{{{smf_app_entry__bootstrap_early}}}
{{{smf_app_entry__bootstrap_platform}}}
{{{smf_app_entry__bootstrap_di}}}
{{{smf_app_entry__bootstrap_late}}}
}
