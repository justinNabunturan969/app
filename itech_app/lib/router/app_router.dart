import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/session/auth_session_storage.dart';
import '../screens/onboarding/launch_loader.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/role_selection/role_selection_screen.dart';
import '../auth/login/student_login_screen.dart';
import '../auth/login/admin_login_screen.dart';
import '../auth/signup/student_signup_screen.dart';
import '../screens/design_system/design_system_screen.dart';
import '../screens/shell/student_shell.dart';
import '../screens/shell/admin_shell.dart';
import '../screens/admin/admin_profile_screen.dart';

/// Router for PUP-ITech Borrowing App.
class AppRouter {
  AppRouter({required this.authStorage, required this.initialLocation});

  final AuthSessionStorage authStorage;
  final String initialLocation;

  GoRouter get router => GoRouter(
    initialLocation: initialLocation,
    redirect: _redirect,
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text(state.error.toString()))),
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) =>
            _fadeScalePage(key: state.pageKey, child: const SplashScreen()),
      ),
      // Post-auth / every-cold-start loader. Shows the wrench zoom
      // animation, then routes to the right home shell based on role.
      // Logged-out users are redirected away (see _redirect below).
      GoRoute(
        path: '/launching',
        name: 'launching',
        pageBuilder: (context, state) => _fadeScalePage(
          key: state.pageKey,
          child: const LaunchLoader(),
        ),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        pageBuilder: (context, state) =>
            _fadeScalePage(key: state.pageKey, child: const WelcomeScreen()),
      ),
      GoRoute(
        path: '/role',
        name: 'role',
        pageBuilder: (context, state) => _rightSlidePage(
          key: state.pageKey,
          child: const RoleSelectionScreen(),
        ),
      ),
      GoRoute(
        path: '/student/login',
        name: 'studentLogin',
        pageBuilder: (context, state) => _leftSlidePage(
          key: state.pageKey,
          child: const StudentLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/student/signup',
        name: 'studentSignup',
        pageBuilder: (context, state) => _leftSlidePage(
          key: state.pageKey,
          child: const StudentSignupScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/login',
        name: 'adminLogin',
        pageBuilder: (context, state) =>
            _leftSlidePage(key: state.pageKey, child: const AdminLoginScreen()),
      ),
      GoRoute(
        path: '/student/shell',
        name: 'studentShell',
        pageBuilder: (context, state) =>
            _fadeScalePage(key: state.pageKey, child: const StudentShell()),
      ),
      GoRoute(
        path: '/admin/shell',
        name: 'adminShell',
        pageBuilder: (context, state) =>
            _fadeScalePage(key: state.pageKey, child: const AdminShell()),
      ),
      GoRoute(
        path: '/admin/profile',
        name: 'adminProfile',
        pageBuilder: (context, state) => _rightSlidePage(
          key: state.pageKey,
          child: const AdminProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/student/design-system',
        name: 'studentDesignSystem',
        pageBuilder: (context, state) => _rightSlidePage(
          key: state.pageKey,
          child: const DesignSystemScreen(),
        ),
      ),
    ],
  );

  Future<String?> _redirect(BuildContext context, GoRouterState state) async {
    final loggedIn = await authStorage.isLoggedIn();
    final role = await authStorage.getRole();
    final loc = state.matchedLocation;

    const authEntryRoutes = {
      '/splash',
      '/welcome',
      '/role',
      '/student/login',
      '/student/signup',
      '/admin/login',
    };

    if (loggedIn && role != null) {
      // /launching is self-terminating (the loader screen navigates to
      // the right shell on its own) — don't redirect away from it.
      if (loc == '/launching') return null;
      if (authEntryRoutes.contains(loc)) {
        // Every cold start with a valid session gets the zoom intro
        // before the home shell mounts.
        return '/launching';
      }
      if (loc.startsWith('/student/') && role != UserRole.student) {
        return '/admin/shell';
      }
      if (loc.startsWith('/admin/') && role != UserRole.admin) {
        return '/student/shell';
      }
      return null;
    }

    if (loc == '/student/shell' || loc == '/admin/shell' || loc == '/launching') {
      return '/role';
    }

    return null;
  }
}

Page<void> _fadeScalePage({required LocalKey? key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
      final scale = Tween<double>(
        begin: 0.98,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

Page<void> _leftSlidePage({required LocalKey? key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offset = Tween<Offset>(
        begin: const Offset(-0.15, 0),
        end: Offset.zero,
      ).animate(curve);
      return SlideTransition(position: offset, child: child);
    },
  );
}

Page<void> _rightSlidePage({required LocalKey? key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offset = Tween<Offset>(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
      ).animate(curve);
      return SlideTransition(position: offset, child: child);
    },
  );
}
