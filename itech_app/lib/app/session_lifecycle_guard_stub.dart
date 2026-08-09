library;

/// Native (non-web) bridge for [SessionLifecycleGuard].
///
/// On Android / iOS / desktop there is no browser `visibilitychange`
/// event — the OS lifecycle is handled by `AppLifecycleListener` in
/// the guard itself. These no-op stubs keep the conditional import
/// happy so the guard compiles on every target.

/// No-op on native platforms (see [documentVisibilityState]).
String? documentVisibilityState() => null;

/// No-op on native platforms.
Object registerVisibilityChange(void Function() onVisible) => Object();

/// No-op on native platforms.
void unregisterVisibilityChange(Object handle) {}
