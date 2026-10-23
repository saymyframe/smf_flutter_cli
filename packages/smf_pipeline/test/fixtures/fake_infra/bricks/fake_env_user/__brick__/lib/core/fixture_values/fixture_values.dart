/// The values of `.env` that the fixture reads (fixture), each through the
/// variable of its key: what `AppEnv` returns for the key in an app with
/// the values in .env, and `null` in an app without them.
abstract final class FixtureValues {
  /// The first value of the fixture.
  static String? get first => {{{env_fake_env_user_first}}};

  /// The second value of the fixture.
  static String? get second => {{{env_fake_env_user_second}}};

  /// The third value of the fixture.
  static String? get third => {{{env_fake_env_user_third}}};
}
