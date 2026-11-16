import '../remote_config/app_remote_config.dart';

/// What the fixture reads of remote config (fixture): the value of each of
/// its parameters, one of each type, which the app has from the backend of
/// the provider, or as the default of the parameter.
abstract final class FixtureRemoteValues {
  /// The greeting of the fixture.
  static String get greeting => appRemoteConfig.value.fakeConfigUserGreeting;

  /// Whether the fixture is on.
  static bool get enabled => appRemoteConfig.value.fakeConfigUserEnabled;

  /// How many the fixture takes.
  static int get limit => appRemoteConfig.value.fakeConfigUserLimit;

  /// The ratio of the fixture.
  static double get ratio => appRemoteConfig.value.fakeConfigUserRatio;
}
