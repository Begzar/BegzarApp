#!/usr/bin/env bash
# Hardened release: begzar_engine XCFramework + obfuscated Flutter macOS .app + ZIP.
#
# Usage:
#   ./scripts/build_macos_release.sh
#   ./scripts/build_macos_release.sh --source=github
#   ./scripts/build_macos_release.sh --source=app_store
#   ./scripts/build_macos_release.sh --skip-begzar
#   ./scripts/build_macos_release.sh --skip-flutter
#   ./scripts/build_macos_release.sh --skip-zip
#   ./scripts/build_macos_release.sh --no-clean
#
# DISTRIBUTION_SOURCE (github | testflight | app_store) is baked in via
# --dart-define. Default: github. Override with --source= or DISTRIBUTION_SOURCE.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SKIP_BEGZAR=0
SKIP_FLUTTER=0
SKIP_ZIP=0
NO_CLEAN=0
SOURCE_CLI=""

for arg in "$@"; do
  case "$arg" in
    --skip-begzar) SKIP_BEGZAR=1 ;;
    --skip-flutter) SKIP_FLUTTER=1 ;;
    --skip-zip) SKIP_ZIP=1 ;;
    --no-clean) NO_CLEAN=1 ;;
    --source=*) SOURCE_CLI="${arg#--source=}" ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $arg${NC}" >&2
      exit 1
      ;;
  esac
done

step() {
  echo ""
  echo -e "${CYAN}==> $1${NC}"
}

die() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=release_hardening.sh
source "$ROOT/scripts/release_hardening.sh"

cd "$ROOT"

PUBSPEC="$ROOT/pubspec.yaml"
DIST_DIR="$ROOT/dist"
DEBUG_INFO_DIR="$ROOT/build/debug-info/macos"
APP_PATH="$ROOT/build/macos/Build/Products/Release/begzar.app"
BIN_PATH="$APP_PATH/Contents/MacOS/begzar"

require_cmd flutter
require_cmd pod
require_cmd zip
require_cmd lipo
require_cmd file

VERSION_RAW="$(
  grep -E '^[[:space:]]*version:' "$PUBSPEC" | head -n1 |
    awk -F: '{print $2}' | tr -d '[:space:]'
)"
[[ -n "$VERSION_RAW" ]] || die "Could not read version from $PUBSPEC"
VERSION_NAME="${VERSION_RAW%%+*}"
[[ "$VERSION_NAME" =~ ^[0-9]+([.][0-9]+)*$ ]] ||
  die "Unexpected version format: '$VERSION_RAW' (name='$VERSION_NAME')"

ARTIFACT_STAMP="Begzar-${VERSION_NAME}-macOS"

resolve_distribution_source macos github "$SOURCE_CLI"

echo -e "${GREEN}Begzar macOS hardened release build${NC}"
echo "Version: $VERSION_NAME (from $VERSION_RAW)"
echo "Source:  $DISTRIBUTION_SOURCE_VALUE"
echo "Root:    $ROOT"
echo "Security: Dart obfuscate + split debug-info + strip binary + no dSYM in dist"

mkdir -p "$DIST_DIR" "$DEBUG_INFO_DIR"

if flutter config --list 2>/dev/null | grep -q 'enable-swift-package-manager: true'; then
  step "Disabling Flutter Swift Package Manager for this machine"
  flutter config --no-enable-swift-package-manager || true
fi

if [[ "$SKIP_BEGZAR" -eq 0 ]]; then
  step "Building begzar_engine macOS universal XCFramework (arm64 + x86_64, stripped)"
  require_cmd go
  require_cmd xcodebuild
  bash "$ROOT/begzar-engine/scripts/build_mac.sh"
  BEGZAR_A="$ROOT/begzar-engine/macos/Frameworks/libbegzar_engine.xcframework/macos-arm64_x86_64/libbegzar_engine.a"
  [[ -f "$BEGZAR_A" ]] || die "begzar_engine archive missing after build: $BEGZAR_A"
else
  step "Skipping begzar_engine build (--skip-begzar)"
fi

# The check above only covers the copy build_mac.sh writes into begzar-engine/. The
# one Runner.xcodeproj actually links lives at macos/libbegzar_engine.xcframework,
# and --skip-begzar reaches Flutter without either being verified.
# pubspec.yaml depends on the open stand-in; a release is built on the private
# engine, which an uncommitted pubspec_overrides.yaml chooses.
step "Choosing the private engine"
bash "$ROOT/scripts/use_engine.sh" private --no-pub-get

step "Verifying the proxy engine is present"
bash "$ROOT/scripts/verify_engine.sh" check macos

if [[ "$SKIP_FLUTTER" -eq 0 ]]; then
  if [[ "$NO_CLEAN" -eq 0 ]]; then
    step "flutter clean (fresh release tree)"
    flutter clean
  fi

  step "flutter pub get"
  flutter pub get

  step "CocoaPods (macos/)"
  (
    cd "$ROOT/macos"
    pod install
  )

  step "flutter build macos (obfuscated release)"
  flutter build macos \
    --release \
    --obfuscate \
    --split-debug-info="$DEBUG_INFO_DIR" \
    --tree-shake-icons \
    --dart-define=FLUTTER_BUILD_MODE=release \
    --dart-define=DISTRIBUTION_SOURCE="$DISTRIBUTION_SOURCE_VALUE"

  step "Verifying Dart obfuscation symbols"
  verify_obfuscation_symbols "$DEBUG_INFO_DIR"
else
  step "Skipping Flutter build (--skip-flutter)"
fi

[[ -d "$APP_PATH" ]] || die "Release app not found: $APP_PATH"
[[ -f "$BIN_PATH" ]] || die "Release binary not found: $BIN_PATH"

step "Stripping release binary + removing dSYM from distributable app"
strip_macos_release_binary "$BIN_PATH"
remove_macos_dsym_from_app "$APP_PATH"
assert_no_debug_symbols_in_tree "$APP_PATH" "macOS .app"

step "Verifying architectures"
file "$BIN_PATH"
lipo -info "$BIN_PATH" || true

if [[ "$SKIP_ZIP" -eq 0 ]]; then
  step "Creating portable ZIP (no debug symbols)"
  PORTABLE_ZIP="$DIST_DIR/${ARTIFACT_STAMP}.zip"
  STAGE="$(mktemp -d "${TMPDIR:-/tmp}/begzar-macos-XXXXXX")"
  STAGE_ROOT="$STAGE/$ARTIFACT_STAMP"
  mkdir -p "$STAGE_ROOT"
  ditto "$APP_PATH" "$STAGE_ROOT/begzar.app"
  assert_no_debug_symbols_in_tree "$STAGE_ROOT" "macOS ZIP stage"

  cat >"$STAGE_ROOT/README.txt" <<EOF
Begzar macOS ${VERSION_NAME}

1. Extract this folder.
2. Open begzar.app (right-click → Open the first time if Gatekeeper blocks it).
3. Universal binary (Apple Silicon + Intel).

EOF

  rm -f "$PORTABLE_ZIP"
  (
    cd "$STAGE"
    zip -qry "$PORTABLE_ZIP" "$ARTIFACT_STAMP"
  )
  rm -rf "$STAGE"
  echo -e "${GREEN}Portable: $PORTABLE_ZIP${NC}"
else
  step "Skipping ZIP (--skip-zip)"
fi

step "Copying .app to dist/ (stripped, no dSYM)"
DIST_APP="$DIST_DIR/${ARTIFACT_STAMP}.app"
rm -rf "$DIST_APP"
ditto "$APP_PATH" "$DIST_APP"
remove_macos_dsym_from_app "$DIST_APP"
assert_no_debug_symbols_in_tree "$DIST_APP" "macOS dist .app"
echo -e "${GREEN}App: $DIST_APP${NC}"

# The packaged files, not the inputs: Flutter writes the build directory into
# the AOT snapshot, so a release built inside a home folder fails here.
step "Scanning release artifacts for machine identity (account, host, local paths)"
PRODUCED=("$DIST_APP")
if [[ "$SKIP_ZIP" -eq 0 ]]; then
  PRODUCED+=("$PORTABLE_ZIP")
fi
assert_no_machine_identity "macOS release artifacts" "$ROOT" "${PRODUCED[@]}"

step "Done"
echo "Artifacts in: $DIST_DIR"
echo "PRIVATE (crash deobfuscation only): $DEBUG_INFO_DIR"
echo "Never publish debug-info/ with release builds."
ls -lah "$DIST_DIR" | sed -n '1,20p'
