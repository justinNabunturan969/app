// test/auth_log_redaction_test.dart
//
// Unit tests for the redaction helper. These cover the regression
// scenarios we care about — a future edit to the regex that loosens
// it should fail this test, not silently leak a token.

import 'package:flutter_test/flutter_test.dart';
import 'package:itech_app/auth/session/auth_log_redaction.dart';

void main() {
  group('AuthLogRedaction.redact', () {
    test('redacts a JWT', () {
      const input =
          'PostgrestException(message: invalid token, details: Bearer eyJabc.def.ghi)';
      final out = AuthLogRedaction.redact(input);
      expect(out, isNot(contains('eyJabc.def.ghi')));
      expect(out, contains('[REDACTED]'));
    });

    test('redacts password= value', () {
      const input = 'RPC error: password=Sup3rSecret! and user=alice';
      final out = AuthLogRedaction.redact(input);
      expect(out, isNot(contains('Sup3rSecret!')));
      expect(out, contains('password=[REDACTED]'));
    });

    test('redacts pwd: value (colon form)', () {
      const input = 'login payload: pwd: hunter2, retries: 3';
      final out = AuthLogRedaction.redact(input);
      // The regex consumes the separator + whitespace between the key
      // and the value, so the replacement is "pwd=[REDACTED]" not
      // "pwd: [REDACTED]". Either form is fine — the secret is gone.
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('[REDACTED]'));
      expect(out, contains('pwd'));
    });

    test('redacts Supabase anon-key-shaped JWT', () {
      // Real JWTs always have three base64url segments separated by
      // dots. A two-segment "eyJ...eyJ..." prefix is what the anon key
      // often looks like when pasted into a config — use a complete
      // 3-segment token here.
      const input =
          'failed to parse: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJpc3MiOiJzdXBhYmFzZSJ9'
          '.Nb1VQlS13rmOlbziFSRzVJR80S069yZtb4G-1VqM3WI';
      final out = AuthLogRedaction.redact(input);
      expect(out, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(out, contains('[REDACTED]'));
    });

    test('redacts long opaque token', () {
      const longToken =
          'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG'; // 44 chars
      const input = 'Authorization header: Bearer $longToken';
      final out = AuthLogRedaction.redact(input);
      expect(out, isNot(contains(longToken)));
    });

    test('leaves a normal error message alone', () {
      const input = 'PostgrestException: relation "borrowings" does not exist';
      final out = AuthLogRedaction.redact(input);
      // No secret-shaped content here; output should be the same.
      expect(out, equals(input));
    });

    test('leaves emails intact by default', () {
      const input = 'Failed to send to juandelacruz@pup.edu.ph';
      final out = AuthLogRedaction.redact(input);
      expect(out, contains('juandelacruz@pup.edu.ph'));
    });

    test('redacts emails when asked', () {
      const input = 'Failed to send to juandelacruz@pup.edu.ph';
      final out = AuthLogRedaction.redact(input, redactEmails: true);
      expect(out, isNot(contains('juandelacruz@pup.edu.ph')));
      expect(out, contains('[REDACTED]'));
    });
  });
}
