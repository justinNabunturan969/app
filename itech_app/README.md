# PUP-ITech Borrowing

Flutter web app for Polytechnic University of the Philippines — Institute of
Technology equipment borrowing system. Supabase handles auth, database, and
real-time updates.

---

## Run locally

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Or use the bundled helper that reads from `supabase.json` (gitignored):

```powershell
.\run.ps1
```

The repo ships with a default Supabase project inlined in
`lib/env/supabase_config.dart`, so a plain `flutter run` (no flags) will
also boot — but with that shared project, not your own. Pass `--dart-define`
flags when you want to point at your own Supabase project.

Do not commit the `supabase.json` file to source control.

See [`SUPABASE_SETUP.md`](./SUPABASE_SETUP.md) for the full backend setup
walkthrough (project creation, migrations, RLS, demo seeding, etc.).

---

## Deploy to Vercel

The project is already wired up for Vercel — push the repo, point Vercel at
it, and the included `vercel.json` + `build.sh` will install Flutter, build
the web bundle, and serve it as a static site with SPA rewrites.

### One-time setup

1. **Import the repo** in Vercel (https://vercel.com/new). Vercel will
   auto-detect the configuration from `vercel.json`. No framework preset
   needed — leave it as "Other".
2. **Override the Supabase project (optional but recommended).** In the
   Vercel project, go to **Settings → Environment Variables** and add:
   - `SUPABASE_URL` — your project's URL (e.g. `https://xxxx.supabase.co`)
   - `SUPABASE_ANON_KEY` — the **anon public** key from
     **Project Settings → API** in Supabase.
   These are read by `build.sh` and passed to `flutter build web` via
   `--dart-define`. If you skip this step, the build will use the
   inlined defaults from `lib/env/supabase_config.dart`.
3. **Allow the Vercel domain in Supabase.** In the Supabase dashboard:
   - **Authentication → URL Configuration** → add your Vercel URL to
     *Site URL* and *Redirect URLs* (e.g. `https://bai-na-bai.vercel.app`
     and `https://bai-na-bai.vercel.app/**`).
   - This is what lets auth callbacks, password resets, and email
     confirmations work end-to-end on the deployed site.
4. **Deploy.** Push to your default branch (or click *Deploy* in the
   Vercel dashboard). The first build takes ~1–2 minutes because it
   clones Flutter from git; subsequent builds reuse the cached clone.

### What `build.sh` does

1. Clones Flutter `stable` into `./flutter` (cached by Vercel across builds).
2. Runs `flutter pub get` to resolve packages.
3. Runs `flutter build web --release` with the env-var overrides (if any).
4. Outputs the static bundle to `build/web/`, which Vercel's
   `outputDirectory` then serves.

### What `vercel.json` does

- `buildCommand` — runs `build.sh` during the Vercel build step.
- `outputDirectory: build/web` — points Vercel at the static bundle.
- `rewrites: { /(.*) → /index.html }` — single-page app routing so deep
  links (e.g. `/equipment/42`) don't 404.
- `headers` — adds basic security headers (X-Frame-Options, etc.) and
  cache hints (1-year immutable for `/assets/` and `/canvaskit/`,
  1-hour for the boot scripts).

### Common deployment problems

| Symptom | Cause | Fix |
|---|---|---|
| `NOT_FOUND` on the deployed URL | Old `vercel.json` with `builds` + no `buildCommand` | Make sure `vercel.json` has the modern `buildCommand` + `outputDirectory` pattern (this repo already does). |
| Build hangs at "Cloning Flutter" | Vercel build sandbox networking issue | Retry; the clone is cached, so this only affects the first deploy. |
| App boots but login fails | Supabase project doesn't allow the Vercel domain | Add the deployed URL to Supabase **Authentication → URL Configuration**. |
| `StateError: Supabase is not configured` in the browser console | Build ran without env vars **and** the inlined defaults were stripped | Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in Vercel env vars, or restore the defaults in `lib/env/supabase_config.dart`. |
| Service worker holds an old build | Browser cache from a prior version | Hard-refresh (Ctrl+Shift+R) or unregister the service worker from DevTools → Application. |

---

## Project layout

```
lib/
├── main.dart                    # boot + Supabase init
├── env/supabase_config.dart     # reads --dart-define (with inlined fallbacks)
├── app/                         # theme, language, app shell
├── auth/                        # sign-in, sign-up, validators, session storage
├── data/
│   ├── models/                  # StudentCard, etc.
│   └── repositories/            # Supabase-backed CRUD + mock fallback
├── router/                      # go_router config
├── screens/                     # all UI
├── services/                    # nfc, etc.
├── student/                     # student-specific controllers & widgets
├── theme/                       # design tokens (PupColors, PupGlass)
└── widgets/                     # shared widgets
supabase/
└── migrations/                  # 0001_initial_schema.sql + later migrations
build.sh                         # Vercel build script
vercel.json                      # Vercel deployment config
```
