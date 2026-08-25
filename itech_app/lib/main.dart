import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_reloader_stub.dart'
    if (dart.library.js_interop) 'app/app_reloader_web.dart';
import 'app/session_lifecycle_guard.dart';
import 'app/theme_controller.dart';
import 'app/language_controller.dart';
import 'auth/session/auth_session_storage.dart';
import 'data/repositories/repository_bundle.dart';
import 'env/supabase_config.dart';
import 'router/app_router.dart';
import 'router/router_app.dart';
import 'screens/onboarding/configuration_required_screen.dart';

late final AuthSessionStorage authSessionStorage;
late final ThemeController themeController;
late final LanguageController languageController;
late final RepositoryBundle repositoryBundle;

/// Convenience accessor used everywhere in the app code.
SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Replace Flutter's default red-error-on-build with a friendlier panel.
  // Without this, a single broken widget on a screen turns the whole tab
  // into an opaque red box that's hard to debug. With it, the user sees
  // the error message right where the broken widget was supposed to be,
  // and the rest of the screen keeps working.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _DebugErrorWidget(
      message: details.exceptionAsString(),
      stack: details.stack?.toString().split('\n').take(6).join('\n') ?? '',
    );
  };

  // A fresh clone does not contain deployment credentials. Previously this
  // threw before runApp(), leaving the user with a blank/crashed application.
  // Keep secrets out of source control but still provide an in-app setup path.
  if (!SupabaseConfig.isConfigured) {
    runApp(const ConfigurationRequiredApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  // The Supabase-backed bundle reads from the live database for every CRUD
  // op, so all of the user-visible actions (approve, reject, return, like,
  // mark read, ...) now persist between launches. The mock factory is still
  // available via `RepositoryBundle.mock()` if you want to demo offline.
  repositoryBundle = RepositoryBundle.fromSupabase();

  authSessionStorage = AuthSessionStorage();
  final initialLocation = await authSessionStorage.getInitialRoute();

  // Hydrate persisted theme preference before the first frame so the app
  // boots directly into the user's chosen mode (no light-mode flash).
  themeController = ThemeController();
  await themeController.load();
  languageController = LanguageController();
  await languageController.load();

  final appRouter = AppRouter(
    authStorage: authSessionStorage,
    initialLocation: initialLocation,
  );

  runApp(
    Provider<RepositoryBundle>.value(
      value: repositoryBundle,
      child: SessionLifecycleGuard(
        userRepository: repositoryBundle.user,
        onForcedLogout: () async {
          // An administrator terminated this session (Login History or
          // Live tab → force logout). Grab the reason while the token
          // still works and PERSIST it — the login screen shows it after
          // the launch animation, surviving any restart in between.
          var reason = 'Your session was ended by an administrator.';
          try {
            final fetched = await repositoryBundle.user
                .consumeForceLogoutNotice();
            if (fetched != null && fetched.isNotEmpty) reason = fetched;
          } catch (_) {
            // Best effort — the default wording still explains the kick.
            // NOTE: if this fires on every kick, migration 0017
            // (`force_logout_notices` + `consume_force_logout_notice`)
            // has not been applied to the database yet.
          }
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(AuthSessionStorage.kickReasonKey, reason);
            // Arm the cold-start replay BEFORE signing out: the fresh boot
            // reads this flag and starts at `/launching?kicked=1`, which
            // guarantees the animation + login-screen hand-off even if the
            // reload lands on a bare origin without the query string.
            await prefs.setBool(AuthSessionStorage.kickReloadPendingKey, true);
          } catch (_) {
            // Best effort.
          }
          try {
            await authSessionStorage.clearSession();
          } catch (_) {
            // Best effort.
          }

          // Reload the app for real — same experience as a first launch:
          // every controller, stream subscription, and cached snapshot is
          // torn down, the wrench rises / glides / types the app name, and
          // the fresh boot ends on the login page with the admin's reason.
          final reloaded = reloadAppToUrl(
            launchReloadUrl('/launching?kicked=1'),
          );
          if (!reloaded) {
            // Native targets can't reload their own engine — replay the
            // launch route inside the living app instead. ALWAYS navigate:
            // even if a step above failed, the device must leave the shell
            // rather than sit on a signed-out shell with error banners.
            appRouter.router.go('/launching?kicked=1');
          }
        },
        child: RouterApp(
          router: appRouter.router,
          themeController: themeController,
          languageController: languageController,
        ),
      ),
    ),
  );
}

/// Friendly inline error panel used by [ErrorWidget.builder] when a widget
/// throws during build. In release builds we collapse this to a tiny
/// "[Error]" pill so a single broken widget doesn't take down the whole
/// screen, but in debug we want the full message so the panel can copy it.
class _DebugErrorWidget extends StatelessWidget {
  const _DebugErrorWidget({required this.message, required this.stack});

  final String message;
  final String stack;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return Container(
        color: const Color(0xFF330000),
        padding: const EdgeInsets.all(8),
        child: const Text(
          '⚠ widget error',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      );
    }
    return Container(
      color: const Color(0xFF2A0A0A),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⚠ Render error',
            style: TextStyle(
              color: Color(0xFFFF8A80),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
          if (stack.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              stack,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontFamily: 'monospace',
                fontSize: 9.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
