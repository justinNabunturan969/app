# Full App Localization — Design

Date: 2026-09-03
Status: approved in brainstorming, pending spec review
Surfaces: student, admin, auth/onboarding, shared widgets
Languages: English (en-US), Tagalog (fil-PH), Cebuano (ceb-PH)

## Problem

The Profile → App language setting persists a choice and switches ~25 strings
(nav labels, language sheet, voice search) through `AppCopy`
(lib/app/language_controller.dart:50). Every other user-visible string in the
app — screens, dialogs, bottom sheets, snackbars, hints, empty states,
validator and error messages, notification and activity text — is hardcoded
English (86+ `Text('` literals across 23 files, plus strings in non-`Text`
positions). Switching language visibly changes almost nothing.

## Goal

Every word of user-visible interface copy renders in the selected language and
switches live when the setting changes, on every surface of the app.

## Non-goals

- Database free text: equipment names/descriptions, admin-entered notes, room
  codes. These have no translation source and pass through as stored.
- Brand strings: `PUP-ITech`, the browser tab title `PUP-ITech Borrowing`.
- Code identifiers, enum names, DB column values used internally.
- Additional languages beyond the existing three; RTL support.

## Architecture

### 1. Catalog files

New directory `lib/app/l10n/`:

- `strings_en.dart`, `strings_tl.dart`, `strings_ceb.dart` — each exports one
  `const Map<String, String>` (`kStringsEn`, `kStringsTl`, `kStringsCeb`) with
  ~400 dot-namespaced keys grouped by surface: `nav.home`,
  `student.home.greeting.morning`, `borrow.sheet.submit`,
  `admin.pending.title`, `auth.login.submit`, `notif.approved.title`, …
- English values are byte-identical to the strings shipped today so the
  existing widget tests keep passing unchanged.

### 2. Typed facade: `AppCopy` (rebuilt in `lib/app/l10n/app_copy.dart`)

- `const AppCopy(this.language)`.
- Core lookup `String t(String key, {Map<String, String> args = const {}})`:
  active-language map → `kStringsEn` fallback → raw key fallback; `{name}`
  placeholders interpolated from `args`.
- One typed getter per key so call sites are compile-checked; parameterized
  strings become methods (`readyFor(name)`, `requestedBy(who, what)`,
  `itemsLeft(n)`), each selecting the per-language template.
- All existing public members (`home`, `analytics`, `borrowings`, `profile`,
  `notifications`, `dashboard`, `live`, `inventory`, `pending`, `scan`,
  `appLanguage`, `chooseAppLanguage`, `appLanguageHelp`, `listening`,
  `readyFor`, `microphoneUnavailable`, `cancel`, `search`,
  `microphoneOrSpeechUnavailable`, `languageNotInstalled`, `languageSelected`)
  keep their names and signatures so the six current call sites compile
  unchanged.
- `LanguageController` stays as-is (persistence + notify); `AppCopy` moves out
  of language_controller.dart, which keeps only the controller and the
  `AppLanguage` enum.

### 3. Context access

`lib/app/l10n/copy_context.dart`:

```dart
extension CopyOnBuildContext on BuildContext {
  AppCopy get copy => AppCopy(watch<LanguageController>().language);
}
```

`watch` makes every screen rebuild on language change. `LanguageController`
is provided app-wide above the router (lib/router/router_app.dart:23), so the
extension also works inside `OverlayEntry` popovers. Non-widget code that
needs copy receives an `AppCopy` parameter; with structured events (§4) the
compose sites no longer need it at all.

### 4. Structured events: notifications + activity log

Problem: notification titles/bodies and activity-log entries are composed as
full English sentences at write time (student_dashboard_controller.dart
~752–1067) and stored (Supabase `notifications` table; persisted local
activity log). A language switch cannot restyle stored sentences.

Design — store events, render sentences at display time:

- Migration `supabase/migrations/0037_notification_params.sql`:
  `alter table public.notifications add column if not exists params jsonb;`
  (nullable; no RLS change). Per project memory this still needs the manual
  SQL Editor step on the live DB.
- `AppNotification` gains `final Map<String, dynamic> params` (default
  `const {}`), read/written by the Supabase notifications repository
  (select, insert, restore).
- Compose sites write `type` + `params` (`who`, `what`, `condition`,
  `quantity`, `studentName`, `studentId`, …) and still write English
  `title`/`body` for backwards compatibility with old rows and old clients.
- Display sites (bell popover, student notifications screen, admin views that
  show notification bodies, `activity_feed`) render through `AppCopy`
  templates keyed by `NotificationType` + `params` when `params` is non-empty;
  rows without params render their stored title/body untouched.
- Local activity-log persistence switches to `{kind, params, ts}` entries;
  the loader accepts the legacy `{title, subtitle, ts}` shape and renders it
  as stored.

### 5. Display-time mappings

`AppCopy` methods map known runtime values to translated labels, passing
unknown values through raw:

- `categoryLabel(String)` — equipment categories (Electrical, Mechanical, …).
- `statusLabel(String)` — borrowing statuses (pending, active, overdue,
  returned, cancelled, return_requested).
- `conditionLabel(String)` — return conditions.
- `authErrorMessage(Object)` — known Supabase auth failures (invalid
  credentials, unconfirmed email, rate limit, network); unknown errors get a
  translated generic message.

### 6. Fallback and edge rules

- Unknown persisted language value → English.
- Missing key in active language → English value → raw key (never blank).
- Empty translation values are forbidden and enforced by the parity test.
- Widgets whose text becomes copy-driven lose their `const` constructors;
  acceptable, no perf-sensitive lists involved.

## Migration order and commits

1. `feat(l10n): catalog infrastructure` — l10n directory, rebuilt `AppCopy`,
   context extension, parity test; existing call sites untouched.
2. `feat(l10n): structured notification events` — migration 0037, model +
   repository params, compose sites, display-time rendering, activity-log
   format.
3. `feat(l10n): shared widgets + student surfaces` — shells' shared widgets,
   home, search + widgets, borrow sheet, borrowings, notifications, profile,
   analytics.
4. `feat(l10n): admin surfaces` — dashboard, inventory + form sheet,
   occupancy, scan, pending requests, return sheet, login history, profile.
5. `feat(l10n): auth + onboarding` — student/admin login, signup, reset,
   role selection, welcome, splash, configuration-required.
6. `feat(l10n): display mappings + language-switch test` — §5 mappings,
   switch test, final sweep for leftover literals.

One push after the full suite is green so Vercel never deploys a
half-migrated build.

## Testing

- `test/l10n_catalog_test.dart` — the three maps expose identical key sets;
  no empty values; sample parameterized methods interpolate correctly.
- `test/language_switch_test.dart` — pump the student shell with
  `RepositoryBundle.mock()` and a real `LanguageController`; switch to
  Tagalog, assert nav + profile copy is Tagalog; switch to Cebuano, assert
  Cebuano; switch back.
- Existing suite (8 tests) stays green unchanged — English copy is identical.
- `flutter analyze` introduces no new issues (2 pre-existing remain).
- Manual pass on `flutter run -d web-server`: switch language on each
  surface, open bell popover, borrow sheet, return sheet, dialogs, empty
  states.

## Risks

- Translation wording drafted by the agent; user reviews in-app and wording
  fixes are one-line map edits.
- Pre-migration notification rows stay English (documented fallback).
- Catalog size (~400 keys × 3) makes the parity test the main safety net
  against key drift.
