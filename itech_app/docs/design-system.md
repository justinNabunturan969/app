# PUP-ITech Design System

> Reference for the thesis appendix. Mirrors the in-app Design System
> page (`Profile → Support → Design System`). All values come from
> `lib/theme/design_tokens.dart`.

---

## 1. Philosophy

The visual language of PUP-ITech Borrowing rests on three ideas:

1. **Tokens, not magic numbers.** Every color, type size, and corner
   radius lives in `PupColors`, `PupTypography`, and the `PupGlass`
   helper class. Screens consume tokens; they do not hardcode hex
   values.
2. **One component, two themes.** Every card, chip, and button is
   drawn from the same source — light mode uses a pastel-tinted fill
   with an accent border, dark mode uses a deep surface with a
   rim-light glow. Same shapes, different atmosphere.
3. **Calm hierarchy.** Titles at `w900`, body at `w700`, metadata
   at `w800` with letter-spacing. The eye should know what's a
   headline and what's a footnote without reading a single word.

---

## 2. Color tokens

All values are `Color` constants on `PupColors` in
`lib/theme/design_tokens.dart`.

### Brand

| Token | Hex | Role |
|---|---|---|
| `pupMaroon` | `#7B1818` | Primary brand. AppBar, primary buttons, institutional markers. |
| `deepMahogany` | `#4A0E0E` | Dark-mode primary surface, deep backgrounds. |
| `coolSteel` | `#F0F2F5` | Light-mode scaffold background. |

### Accents

| Token | Hex | Role |
|---|---|---|
| `cyberAmber` | `#FFB800` | Active state, primary CTAs, "in use" markers, positive highlights. |
| `techCyan` | `#00B4D8` | Neutral-active state, available equipment, info chips. |
| `mintGreen` | `#06D6A0` | Success, returned, unlocked, "all good" states. |
| `signalRed` | `#EF476F` | Overdue, error, destructive actions, notification badges. |

### Text

| Token | Hex | Role |
|---|---|---|
| `slateGray` | `#1E293B` | Primary text in light mode. |
| `ashGray` | `#64748B` | Secondary text, captions, helper lines. |

### Surfaces

| Token | Hex | Role |
|---|---|---|
| `lightCard` | `#FFFFFF` | Opaque card fill, light mode. |
| `lightCardAlt` | `#F8F9FC` | Subtle surface variant, light mode (also bottom nav bg). |
| `darkCard` | `#1E293B` | Card fill, dark mode. |
| `darkCardAlt` | `#162032` | Subtle surface variant, dark mode. |

### Pastel glows (light mode only)

| Token | Hex | Role |
|---|---|---|
| `lightGlowAmber` | `#FFF8E1` | Tinted stat card background. |
| `lightGlowCyan` | `#E1F7FF` | Tinted stat card background. |
| `lightGlowGreen` | `#E1FCF0` | Tinted stat card background. |
| `lightGlowRed` | `#FFE8EE` | Tinted stat card / overdue surface. |

---

## 3. Typography

`PupTypography.textThemeFor(base)` derives the app's text theme from
the platform base. The custom overrides are limited and intentional.

| Role | Size | Weight | Letter-spacing | Use |
|---|---|---|---|---|
| Display | 22 | w900 | – | Screen titles ("My Borrowings", "Profile") |
| Title | 15 | w900 | – | Section headers inside cards |
| Body | 13 | w700 | – | Card titles, list rows, default reading |
| Label | 11 | w800 | +0.4 | Section eyebrow text, status pill text |
| Caption | 12 | w700 | – | Timestamps, helper lines, metadata |

**Light/dark mapping:**

- Light mode: `PupColors.slateGray` for primary text,
  `PupColors.ashGray` for secondary.
- Dark mode: `theme.colorScheme.onSurface` for primary,
  `onSurface.withValues(alpha: 0.75)` for secondary.

---

## 4. Spacing, radii, shadows

- **Page padding:** 16 px horizontal, 16 px top, 6–24 px bottom.
- **Card padding:** 12–14 px.
- **Card border radius:** 16–18 px.
- **Pill / chip radius:** 999 (fully rounded).
- **Icon chip size:** 34–42 px square; 11–14 px corner radius.
- **Shadows:** every elevated card has a tinted shadow whose color is
  the card's accent, not gray. Light mode uses `PupGlass.lightShadow`
  (tinted + a 4 % black contact shadow); dark mode uses
  `PupGlass.darkEnhancedGlow` (outer ambient + inner rim + black base).

---

## 5. Components

### 5.1 Toned icon chip

A rounded square with a gradient fill (accent at 32 % → 8 % opacity),
a 1.1 px border in the accent, a colored drop shadow, and a centered
icon. Used everywhere an action or category needs a visual marker
without taking up full card space.

```dart
Container(
  width: 42, height: 42,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [tone.withValues(alpha: 0.32), tone.withValues(alpha: 0.08)],
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.1),
    boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.18), blurRadius: 12)],
  ),
  child: Icon(icon, color: tone, size: 22),
)
```

### 5.2 Status pill

Small, fully-rounded pill used on cards to label state.

- 8 px horizontal, 3 px vertical padding.
- Fill: `accent.withValues(alpha: 0.12)`.
- Border: `accent.withValues(alpha: 0.4)`, 0.8 px.
- Text: `accent`, `w900`, 10 px, +0.4 letter-spacing.

### 5.3 Filter / category chip

Larger, interactive chip used to filter lists.

- 14 px horizontal, 8 px vertical padding.
- Idle: transparent fill, ash-gray border, slate text.
- Selected: amber fill, dark text, amber drop shadow.

### 5.4 Stat card (summary)

A 170 × 118 card with a tinted icon chip + a single label string
(usually `"Active: 3"`). Uses `PupGlass.statCardGlow` and a press-state
swap to `PupGlass.pressedDecoration`.

### 5.5 PupGlass surfaces

The `PupGlass` helper class provides three surface treatments:

- `PupGlass.container` — generic surface with optional pastel glow.
- `PupGlass.glowContainer` — stronger glow, for stat cards and
  highlighted equipment.
- `PupGlass.statCardGlow` — pastel-glow variant; the default for
  metric cards.

Each returns a `BoxDecoration` whose colors, borders, and shadows are
theme-aware (light vs. dark detected via `Theme.of(context).brightness`).

### 5.6 Buttons

- **Primary** (`FilledButton`): amber fill, near-black foreground,
  `w800`, 10 px corner radius.
- **Secondary** (`OutlinedButton`): maroon border at 50 % opacity,
  maroon text.
- **Destructive** (logout, clear all): red fill or border, white or
  red foreground depending on `FilledButton` vs `OutlinedButton`.

---

## 6. Light / dark theming

The app is fully theme-aware via `themeMode` on `MaterialApp.router`,
driven by a `ThemeController` (`ChangeNotifier`). Every screen reads
`Theme.of(context).brightness` and branches on it.

The rule of thumb:

- **Light mode** = pastel-tinted fills + accent-tinted shadows. The
  surface reads as warm paper; the accent reads as ink.
- **Dark mode** = deep surface + rim-light glow. The surface reads as
  a backlit panel; the accent reads as a neon highlight.

Toggle the theme from any screen via the icon button in the top-right
(the same one used across Home, Borrowings, Profile, and the Design
System page).

---

## 7. Motion

- **Page transitions:** custom `CustomTransitionPage` builders in
  `app_router.dart` — fade + scale for shells, horizontal slide for
  pushed routes.
- **Card entrance:** the Borrowings tab uses a 700 ms staggered
  fade-in + slide-up on first build (`Interval`-based, caps at 7
  items).
- **Haptics:** `HapticFeedback.selectionClick()` for taps, `.lightImpact()`
  for confirmations, `.mediumImpact()` for destructive actions.
- **Tickers:** the dashboard controller runs a 1-second `Timer.periodic`
  to drive live countdowns, relative-time labels, and any other
  time-derived UI.

---

## 8. Accessibility notes

- All interactive elements have a `tooltip` (mic, clear, back, theme).
- Color is never the only signal — every status pill is paired with a
  text label, every unread notification has a dot, every overdue item
  has a red "Overdue" pill plus a red progress bar.
- Tap targets on chips and pills are at least 40 × 40 effective hit
  area.
- Dark mode is a first-class theme, not a "night skin" — colors are
  chosen for legibility on the deep surface, not just inverted.
