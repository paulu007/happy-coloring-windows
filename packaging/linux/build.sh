#!/usr/bin/env bash
set -euo pipefail
# Build Linux release bundle and archives locally.
# Requires flutter SDK + libgtk-3-dev, cmake, ninja, clang.

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH. Install via https://docs.flutter.dev/get-started/install/linux"
  exit 1
fi

flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release

BUNDLE="build/linux/x64/release/bundle"
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
SAFE_VERSION="${VERSION:-0.0.0}"
OUT="HappyColor-Linux-x64-${SAFE_VERSION}.tar.gz"
tar -czf "$OUT" -C "$BUNDLE" .
echo "Created $OUT"
ls -lh "$OUT"

if command -v fpm >/dev/null 2>&1; then
  fpm -s dir -t deb -n happy-color -v "$SAFE_VERSION" -C "$BUNDLE" . \
    --description "Happy Color — numbers hidden but detectable" --license MIT || true
  ls -lh happy-color*.deb || true
else
  echo "fpm not found — skipping .deb (gem install fpm to enable)"
fi
