#!/usr/bin/env bash
# setup.sh — Bootstrap the ATC Frequencies Flutter project
# Run this once after cloning / downloading the source files.
# Requires Flutter SDK: https://docs.flutter.dev/get-started/install

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║     ATC Frequencies — Setup           ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# ── 1. Check Flutter ──────────────────────────────────────────────────────────
if ! command -v flutter &>/dev/null; then
  echo "❌  Flutter not found."
  echo "    Install it from: https://docs.flutter.dev/get-started/install"
  exit 1
fi
echo "✅  Flutter $(flutter --version --machine 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('frameworkVersion',''))" 2>/dev/null || echo 'detected')"

# ── 2. Create the Flutter scaffold in a temp dir, then merge ──────────────────
echo ""
echo "🔧  Creating Flutter project scaffold…"
TEMP_DIR=$(mktemp -d)
flutter create \
  --org com.atcfreq \
  --project-name atc_freq \
  --platforms android,ios \
  "$TEMP_DIR/atc_freq" \
  --quiet

# Copy platform boilerplate we don't ship (Xcode project, Gradle files, etc.)
echo "📁  Merging platform scaffolding…"

# Android
rsync -a --ignore-existing "$TEMP_DIR/atc_freq/android/" "$SCRIPT_DIR/android/"
# iOS
rsync -a --ignore-existing "$TEMP_DIR/atc_freq/ios/" "$SCRIPT_DIR/ios/"
# Keep our Info.plist and AndroidManifest — don't let rsync overwrite them
cp "$SCRIPT_DIR/android/app/src/main/AndroidManifest.xml" \
   "$TEMP_DIR/atc_freq/android/app/src/main/AndroidManifest.xml"

rm -rf "$TEMP_DIR"

# ── 3. Install dependencies ───────────────────────────────────────────────────
echo ""
echo "📦  Installing pub dependencies…"
flutter pub get

# ── 4. Verify ────────────────────────────────────────────────────────────────
echo ""
echo "🔍  Analysing code…"
flutter analyze --no-fatal-infos || true

# ── 5. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Setup complete!                                          ║"
echo "║                                                           ║"
echo "║  Run on Android:  flutter run -d android                 ║"
echo "║  Run on iOS:      flutter run -d ios                     ║"
echo "║  Build APK:       flutter build apk --release            ║"
echo "║  Build IPA:       flutter build ios --release            ║"
echo "║                                                           ║"
echo "║  Airport data (~9 MB) downloads automatically on first   ║"
echo "║  launch and refreshes weekly in the background.          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
