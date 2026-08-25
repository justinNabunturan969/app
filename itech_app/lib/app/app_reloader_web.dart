library;

import 'dart:js_interop';

/// Web bridge for the forced-logout reload.
///
/// An administrator force-logout must look exactly like a fresh app start:
/// every stale controller, stream subscription, and cached snapshot has to
/// die. Swapping routes inside the living widget tree leaves too much state
/// alive, so on the web we do a genuine browser reload pointed at the
/// launch route — the LaunchLoader animation plays from scratch and then
/// lands on the login screen with the admin's reason.
///
/// `location.replace` (not `href =`) is used so the back button can never
/// return the user to the dead, signed-out shell they were just kicked out
/// of. This file is selected by the conditional import in `app_reloader`
/// consumers when `dart.library.js_interop` is available.

@JS('window.location.replace')
external void _locationReplace(String url);

/// Navigates the browser to [url] as a full page load. Always returns
/// `true` — the navigation happens asynchronously but is guaranteed to be
/// initiated (the current page is torn down immediately afterwards).
bool reloadAppToUrl(String url) {
  _locationReplace(url);
  return true;
}

/// Absolute URL for a hash-router path, e.g. `/#/launching?kicked=1`,
/// rooted at the current origin.
String launchReloadUrl(String hashPath) {
  final origin = Uri.base.origin;
  return '$origin/#$hashPath';
}