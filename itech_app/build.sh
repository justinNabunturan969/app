#!/bin/bash
# Vercel build script for the PUP-ITech Flutter web app.
#
# Vercel's build environment doesn't ship with Flutter, so we clone the
# stable channel into the build sandbox and use it for `pub get` and
# `flutter build web --release`. The result lands in `build/web/`, which
# Vercel's `outputDirectory` in `vercel.json` then serves as a static
# site.
#
# The clone is cached between builds, so only the first build is slow.
# Subsequent builds skip the git clone step via Vercel's filesystem
# cache.
set -euo pipefail

# 1. Install Flutter (cached across builds by Vercel).
if [ ! -d "flutter" ]; then
  echo "==> Cloning Flutter stable"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git
fi
export PATH="$PATH:$(pwd)/flutter/bin"

# 2. Silence the analytics phone-home that the first run triggers.
flutter --disable-analytics
flutter config --no-cli-animations >/dev/null 2>&1 || true

# 3. Resolve packages.
echo "==> Resolving packages"
flutter pub get

# 4. Build for the web.
#    --release: production-mode Dart compiler.
#    --no-wasm-dry-run: skip the wasm dry-run warning (we ship JS).
#    --no-tree-shake-icons: keep all material icons in the bundle so the
#      first paint doesn't have to re-fetch them over the network.
echo "==> Building web bundle"
flutter build web \
  --release \
  --no-wasm-dry-run \
  --no-tree-shake-icons
