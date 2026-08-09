import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/user_repository.dart';
import 'session_lifecycle_guard_stub.dart'
    if (dart.library.js_interop) 'session_lifecycle_guard_web.dart';

/// Keeps the current user's `active_sessions` row in sync with the
/// app's actual lifecycle.
///
/// The row is created on `initState` and refreshed every 30 seconds
/// while the app is alive, so the admin's Live tab reflects the user
/// in near real time. We **never** drop the row on `onPause`,
/// `onHide`, `visibilitychange → hidden`, or `pagehide`: on the web
/// every one of those fires whenever the student switches tabs, locks
/// their phone, or lets the screen sleep — the user is still on the
/// device and may be back in a second, so a missing row would be
/// misleading. The server's `expire_stale_sessions` sweep (2-minute
/// threshold, called from the admin's `getActiveSessions`) handles
/// users who have actually left; the heartbeat keeps everyone else
/// visible.
///
/// We do react to the *positive* half of those signals: when the page
/// comes back to the foreground (`onResume`, `onShow`, or
/// `visibilitychange → visible`), we re-mark the user online
/// immediately so the row is restored within milliseconds instead of
/// waiting for the next 30-second heartbeat tick.
///
/// The only place we proactively call `removeOwnSession` is
/// `onDetach` (native engine teardown). On the web we deliberately
/// do **not** hook `pagehide` — that event fires on bfcache
/// transitions and mobile screen-off, which is far more often than
/// a real tab close, and was deleting the row while the user was
/// still on the device. The 2-minute server-side sweep covers the
/// genuine "tab closed and forgotten" case.
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
  Object? _webVisibilityHandle;
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
    // are *temporary* absences. We deliberately do nothing on those
    // signals (see class docstring): the 30s heartbeat below keeps
    // the row fresh, the server's `expire_stale_sessions` cleans up
    // users who are truly gone, and we re-mark the user online the
    // moment they come back via `onResume` / `onShow`.
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
      // On the web there is no `onResume` for tab switches — the
      // browser may have throttled or paused our Timer while the
      // tab was hidden. Listen for `visibilitychange` and the
      // moment the page is visible again, refresh the row so a
      // returning student shows up on the admin's Live tab within
      // milliseconds instead of waiting up to 30s for the next
      // heartbeat tick. We do **not** drop the row on `hidden` —
      // see the class docstring for why that was the bug.
      _webVisibilityHandle = registerVisibilityChange(() {
        unawaited(_markOnline());
      });
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _heartbeat?.cancel();
    _authSubscription?.cancel();
    if (kIsWeb && _webVisibilityHandle != null) {
      unregisterVisibilityChange(_webVisibilityHandle!);
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
