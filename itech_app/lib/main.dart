import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  runApp(
    Provider<RepositoryBundle>.value(
      value: repositoryBundle,
      child: SessionLifecycleGuard(
        // Drops the current user's `active_sessions` row whenever
        // the app is backgrounded, hidden, detached, or (on web)
        // the tab is closed. Re-registers the row on resume/show
        // so the admin's Live tab stays accurate.
        userRepository: repositoryBundle.user,
        child: RouterApp(
          router: AppRouter(
            authStorage: authSessionStorage,
            initialLocation: initialLocation,
          ).router,
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
