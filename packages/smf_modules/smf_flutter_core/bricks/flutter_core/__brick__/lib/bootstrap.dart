{{{smf_app_entry__top_level}}}

/// Runs the start-up code of the app before its first frame: first what
/// must come before anything else, then the platform services, then the
/// services of the app, then what needs them.
Future<void> bootstrap() async {
{{{smf_app_entry__bootstrap_early}}}
{{{smf_app_entry__bootstrap_platform}}}
{{{smf_app_entry__bootstrap_di}}}
{{{smf_app_entry__bootstrap_late}}}
}
