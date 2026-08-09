import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/user_repository.dart';

/// Keeps the current user's `active_sessions` row in sync with the
/// app's actual lifecycle.
///
/// The row is created on `initState` and refreshed every 30 seconds
/// while the app is alive, so the admin's Live tab reflects the user
/// in near real time. We do **not** drop the row on `onPause` /
/// `onHide`: on the web those fire every time the student switches
/// tabs or loses window focus, and on mobile every time the app is
/// backgrounded — in both cases the user is still on the device and
/// may be back in a second, so a missing row would be misleading.
/// The server's `expire_stale_sessions` sweep (2-minute threshold,
/// called from the admin's `getActiveSessions`) handles users who
/// have actually left; heartbeats keep everyone else visible.
///
/// The only places we proactively call `removeOwnSession` are
/// `onDetach` (native engine teardown) and the browser's `pagehide`
/// event (best-effort — the browser will not wait for the Supabase
/// round-trip, so a stale row may briefly linger; the next admin
/// query will sweep it).
class SessionLifecycleGuard extends StatefulWidget {
  const SessionLifecycleGuard({
    super.key,
    required this.userRepository,
    required this.child,
  });

  final UserRepository userRepository;
  final Widget child;

  @override
  State<SessionLifecycleGuard> createState() => _SessionLifecycleGuardState();
}

class _SessionLifecycleGuardState extends State<SessionLifecycleGuard> {
  AppLifecycleListener? _listener;
  JSFunction? _webCleanupFn;
  Timer? _heartbeat;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Register the session row on first mount, before the first
    // 30-second heartbeat. Without this, the row only appears after
    // the first tick — long enough for the admin's Live tab to
    // briefly show "0 online" right after the student signs in, and
    // long enough for `expire_stale_sessions` to have swept a row
    // that was never re-created on a page refresh.
    unawaited(_markOnline());

    // A cold app starts before Supabase restores its persisted session, so the
    // first call above can legitimately find no signed-in user. Listen for
    // the completed auth event and immediately create the presence row then;
    // this also covers sign-ins from a second device without waiting for the
    // next 30-second heartbeat.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      switch (data.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          if (data.session != null) unawaited(_markOnline());
        default:
          break;
      }
    });

    // `onPause` / `onHide` fire when the user switches tabs, loses
    // window focus, or backgrounds the app on mobile — all of which
    // are *temporary* absences. The 30s heartbeat below keeps the
    // row fresh; the server's `expire_stale_sessions` (2-minute
    // threshold) cleans up rows whose owner is truly gone. We only
    // drop the row on `onDetach` (native engine teardown), which is
    // the actual "user has left" event.
    _listener = AppLifecycleListener(
      onDetach: _markOffline,
      onResume: _markOnline,
      onShow: _markOnline,
    );
    // Browsers do not guarantee an async network request on close.
    // Refresh the lease while the app is visible so the server can
    // expire abandoned sessions shortly after a tab/app disappears.
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_markOnline());
    });

    if (kIsWeb) {
      _webCleanupFn = _registerPageHide((_) {
        // Fire and forget — the page is unloading and we cannot
        // block on the Supabase round-trip. The next admin query
        // will sweep the row if the round-trip is dropped.
        unawaited(_markOffline());
      });
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _heartbeat?.cancel();
    _authSubscription?.cancel();
    if (kIsWeb && _webCleanupFn != null) {
      _unregisterPageHide(_webCleanupFn!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _markOffline() async {
    try {
      await widget.userRepository.removeOwnSession();
    } catch (_) {
      // Best effort. A stale row is acceptable here.
    }
  }

  Future<void> _markOnline() async {
    try {
      await widget.userRepository.markOwnSessionActive();
    } catch (_) {
      // Best effort.
    }
  }
}

// ── Web bridge ────────────────────────────────────────────────────────
// dart:js_interop is available on every platform, but `window` and
// `addEventListener` only exist on the web target. We guard the call
// site with `kIsWeb` (above) and the externs themselves are wrapped in
// a JS-accessible shape so the call is type-safe from Dart.

@JS('window.addEventListener')
external void _windowAddEventListener(JSAny type, JSAny listener);

@JS('window.removeEventListener')
external void _windowRemoveEventListener(JSAny type, JSAny listener);

JSFunction _registerPageHide(void Function(JSObject event) handler) {
  final fn = ((JSObject e) => handler(e)).toJS;
  _windowAddEventListener('pagehide'.toJS, fn);
  return fn;
}

void _unregisterPageHide(JSFunction fn) {
  _windowRemoveEventListener('pagehide'.toJS, fn);
}
