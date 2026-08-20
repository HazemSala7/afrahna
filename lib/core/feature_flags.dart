/// Global feature flags for toggling parts of the app on/off from one place.
library;

/// Whether the points / rewards system is surfaced anywhere in the UI.
///
/// Hidden for now. When this is `false` the app does not show:
///   * the gold points-balance card on the home page,
///   * the invite-a-friend rewards card on the home page,
///   * the "نقاطي ومكافآتي" entry in the account menu.
///
/// To bring the points system back, either flip the default below to `true`
/// or build with `--dart-define=SHOW_POINTS=true`.
const bool kShowPointsSystem =
    bool.fromEnvironment('SHOW_POINTS', defaultValue: false);

/// Whether the reach-statistics band ("14 مدينة · 23.0K مستخدم · …") appears
/// at the bottom of the home page.
///
/// Hidden. The numbers are still collected and still shown in the dashboard;
/// this only decides whether the home page carries them.
///
/// To bring it back, flip the default below or build with
/// `--dart-define=SHOW_HOME_STATS=true`.
const bool kShowHomeStats =
    bool.fromEnvironment('SHOW_HOME_STATS', defaultValue: false);
