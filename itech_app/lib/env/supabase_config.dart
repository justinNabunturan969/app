import 'package:flutter/foundation.dart';

/// Supabase project credentials. These come from your project's dashboard at
/// https://supabase.com/dashboard/project/_/settings/api
///
/// Credentials are **never inlined in source**. Provide them at build time:
///
/// 1. **Local dev / native builds** — pass with `--dart-define`, or use the
///    git-ignored `supabase.local.json` loaded by `run.ps1` via
///    `--dart-define-from-file`.
/// 2. **Vercel / web deploy** — pass the same flags to `flutter build web`
///    in your CI/deploy script (e.g. from environment variables / secrets).
///
/// The Supabase *anon* key is designed to be public (it ships in every
/// browser request) and RLS policies are what actually protect data — but
/// keeping it out of source control still prevents key reuse across
/// environments and makes rotation painless.
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
class SupabaseConfig {
  const SupabaseConfig._();

  // No defaults on purpose. A missing flag fails fast and loudly at
  // startup (see [assertConfigured]) instead of silently pointing a dev
  // build at a production project.
  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Where Supabase returns the user after they open a password-reset email.
  ///
  /// For web builds the current origin is used automatically, which makes
  /// preview and production Vercel deployments work without hard-coding a
  /// domain. Native builds use the app's registered deep link. A deployment
  /// may override either with `--dart-define=PASSWORD_RESET_REDIRECT_URL=...`.
  static String get passwordResetRedirectUrl {
    const configured = String.fromEnvironment('PASSWORD_RESET_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return Uri.base.resolve('/reset-password').toString();
    return 'pupitech://auth/reset-password';
  }

  /// True if both URL and anon key resolved to a non-empty value. With
  /// the inlined defaults this is always true for production builds, but
  /// the check is still useful for local dev where someone might delete
  /// the defaults.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Throws a startup-friendly error if both the inlined defaults and
  /// the `--dart-define` overrides are empty. Called from `main()` so
  /// the failure mode is obvious (the app never silently talks to a
  /// random project).
  static void assertConfigured() {
    if (isConfigured) return;
    throw StateError(
      'Supabase is not configured.\n'
      '\n'
      'Run the app with --dart-define for both:\n'
      '  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co\n'
      '  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY\n'
      '\n'
      'Get these from your Supabase project:\n'
      '  Project Settings -> API -> Project URL / anon public key',
    );
  }
}
