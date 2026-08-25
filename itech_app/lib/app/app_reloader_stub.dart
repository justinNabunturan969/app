library;

/// Native (non-web) stub for the forced-logout reload.
///
/// Android / iOS / desktop builds cannot reload their own engine from
/// Dart, so this reports failure and callers fall back to an in-app
/// navigation that replays the same launch animation route.

/// No-op on native platforms — returns `false` so callers fall back to
/// an in-app `router.go(...)`.
bool reloadAppToUrl(String url) => false;

/// Not meaningful on native platforms; returned unchanged.
String launchReloadUrl(String hashPath) => hashPath;