/// Internal-testing flag. When true, every paywall/subscription/tariffs
/// surface is hidden and all features stay accessible.
/// Enable with: --dart-define=BYPASS_PAYWALL=true
/// Default false → production builds are unaffected.
const bool kBypassPaywall =
    bool.fromEnvironment('BYPASS_PAYWALL', defaultValue: false);
