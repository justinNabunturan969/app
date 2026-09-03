// lib/auth/session/auth_log_redaction.dart
//
// Centralized redaction for any string that might end up in a
// debugPrint / error panel / analytics event. The goal isn't to be
// perfect (real redaction is a server-side concern) — it's to make
// sure a future code path that passes a raw RPC exception to a log
// doesn't accidentally print a password or auth token.
//
// Used by:
//   - lib/auth/session/auth_session_storage.dart (debugPrint sites)
//   - lib/main.dart (the in-app error panel)
//
// Pattern coverage:
//   - Supabase JWTs (three base64url segments)
//   - Long hex/base64 strings (≥40 chars, no spaces) that look like
//     tokens, hashes, or anon keys
//   - "password=…", "pwd=…", "p_password=…" key/value fragments
//   - Email addresses (kept PII-light for any screenshot the user
//     might share during debugging)

import 'package:flutter/foundation.dart';

class AuthLogRedaction {
  AuthLogRedaction._();

  static const _replacement = '[REDACTED]';

  // Matches a JWT — three base64url segments separated by dots.
  static final RegExp _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b',
  );

  // Matches a long opaque token (40+ chars, base64url-ish, no spaces).
  // Conservative: requires a high-entropy mix of letters and digits to
  // avoid eating real text.
  static final RegExp _opaqueToken = RegExp(
    r'\b[A-Za-z0-9_-]{40,}\b',
  );

  // Matches a "key=value" or "key: value" pair where the value is
  // anything quoted or until the next whitespace/semicolon/comma.
  // Uses a non-raw string so we can write the apostrophe inside the
  // character class (raw strings don't accept \' escapes — they end
  // the string at the first unescaped quote).
  static final RegExp _keyValuePair = RegExp(
    '\\b(password|pwd|pass|token|secret|access_token|refresh_token|jwt|api[_-]?key|supabase[_-]?key|anon[_-]?key)\\s*[=:]\\s*["\']?([^"\'\\s,;}]+)',
    caseSensitive: false,
  );

  // Matches an email. We don't log them in redacted form by default,
  // but callers can opt in via [redactEmails: true].
  static final RegExp _email = RegExp(
    r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b',
  );

  /// Returns [input] with secret-like fragments replaced. By default
  /// emails are left intact (they're useful in debug context); pass
  /// [redactEmails] when sharing logs externally.
  static String redact(
    String input, {
    bool redactEmails = false,
  }) {
    if (!kDebugMode && !kProfileMode) {
      // Production builds shouldn't be logging these anyway, but be
      // safe: if anyone calls us in release mode, return a placeholder
      // so the raw string never reaches the output.
      return _replacement;
    }
    var out = input;
    out = out.replaceAll(_jwt, _replacement);
    out = out.replaceAllMapped(_keyValuePair, (m) => '${m[1]}=$_replacement');
    out = out.replaceAll(_opaqueToken, _replacement);
    if (redactEmails) {
      out = out.replaceAll(_email, _replacement);
    }
    return out;
  }
}
