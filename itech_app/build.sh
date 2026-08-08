#!/bin/bash
# Vercel build script for the PUP-ITech Flutter web app.
#
# Vercel's build sandbox doesn't ship with Flutter, so we clone the
# stable channel into the build sandbox and use it for `pub get` and
# `flutter build web --release`. The result lands in `build/web/`, which
# Vercel's `outputDirectory` in `vercel.json` then serves as a static
# site.
#
# The clone is cached between builds via Vercel's filesystem cache, so
# only the first build is slow. Subsequent builds skip the git clone
# step.
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────
# 0. Diagnostics — Vercel build logs surface this immediately.
# ─────────────────────────────────────────────────────────────────────
echo "==> Build started at $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "==> Working dir: $(pwd)"
echo "==> Flutter target: stable"

# ─────────────────────────────────────────────────────────────────────
# 1. Install Flutter (cached across builds by Vercel).
# ─────────────────────────────────────────────────────────────────────
if [ ! -d "flutter" ]; then
  echo "==> Cloning Flutter stable (first build only — ~30s)"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git
else
  echo "==> Reusing cached Flutter checkout at ./flutter"
fi
export PATH="$PATH:$(pwd)/flutter/bin"

# ─────────────────────────────────────────────────────────────────────
# 2. Silence the analytics phone-home that the first run triggers.
# ─────────────────────────────────────────────────────────────────────
flutter --disable-analytics >/dev/null 2>&1 || true
flutter config --no-cli-animations >/dev/null 2>&1 || true

# Print the resolved Flutter version so build logs are self-describing.
echo "==> Using Flutter $(flutter --version | head -n 1)"

# ─────────────────────────────────────────────────────────────────────
# 3. Resolve packages.
# ─────────────────────────────────────────────────────────────────────
echo "==> Resolving packages"
flutter pub get

# ─────────────────────────────────────────────────────────────────────
# 4. Build for the web.
#    --release:        production-mode Dart compiler.
#    --no-wasm-dry-run: skip the wasm dry-run warning (we ship JS).
#    --no-tree-shake-icons: keep all material icons in the bundle so the
#      first paint doesn't have to re-fetch them over the network.
#
#    Supabase credentials (if any) are read from the inlined defaults
#    in lib/env/supabase_config.dart, so no --dart-define is required
#    here. To override per-build, set SUPABASE_URL and SUPABASE_ANON_KEY
#    in the Vercel project settings and the build will pick them up.
# ─────────────────────────────────────────────────────────────────────
DART_DEFINES=""
if [ -n "${SUPABASE_URL:-}" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=SUPABASE_URL=${SUPABASE_URL}"
fi
if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
fi

echo "==> Building web bundle (release)"
# shellcheck disable=SC2086
flutter build web \
  --release \
  --no-wasm-dry-run \
  --pwa-strategy=none \
  --no-tree-shake-icons \
  $DART_DEFINES

# Retire app-shell workers created by older Flutter builds. The file is kept at
# the legacy URL because installed copies ask the browser to update that exact
# service-worker script before they can receive the new bundle.
cp web/service_worker_cleanup.js build/web/flutter_service_worker.js

echo "==> Build finished at $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "==> Output: build/web/ ($(du -sh build/web 2>/dev/null | cut -f1))"
