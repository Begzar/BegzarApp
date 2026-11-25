#!/usr/bin/env bash
# Hardened release: begzar_engine (.so) + R8/ProGuard + obfuscated Flutter APK/AAB.
# Debug symbols go to build/debug-info/android (never ship in dist/).
#
# Usage:
#   ./scripts/build_android_release.sh
#   ./scripts/build_android_release.sh --bundle
#   ./scripts/build_android_release.sh --source=github
#   ./scripts/build_android_release.sh --bundle --source=google_play
#   ./scripts/build_android_release.sh --skip-begzar
#   ./scripts/build_android_release.sh --skip-flutter
#   ./scripts/build_android_release.sh --split-per-abi
#   ./scripts/build_android_release.sh --abi=arm64-v8a
#   ./scripts/build_android_release.sh --no-clean
#
# --abi= builds the engine and the APK for that one ABI only, named as the
# --split-per-abi file for it is: one Go build instead of three.
#
# DISTRIBUTION_SOURCE (github | google_play) is baked in via --dart-define.
# Default: github for APK, google_play for --bundle. Override with --source=
# or the DISTRIBUTION_SOURCE env var.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SKIP_BEGZAR=0
SKIP_FLUTTER=0
SPLIT_PER_ABI=0
BUILD_BUNDLE=0
NO_CLEAN=0
SOURCE_CLI=""
ONLY_ABI=""

for arg in "$@"; do
  case "$arg" in
    --skip-begzar) SKIP_BEGZAR=1 ;;
    --skip-flutter) SKIP_FLUTTER=1 ;;
    --split-per-abi) SPLIT_PER_ABI=1 ;;
    --bundle) BUILD_BUNDLE=1 ;;
    --no-clean) NO_CLEAN=1 ;;
    --source=*) SOURCE_CLI="${arg#--source=}" ;;
    --abi=*) ONLY_ABI="${arg#--abi=}" ;;
    -h|--help)
      sed -n '2,24p' "$0"
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
DEBUG_INFO_DIR="$ROOT/build/debug-info/android"
APK_DIR="$ROOT/build/app/outputs/flutter-apk"
AAB_DIR="$ROOT/build/app/outputs/bundle/release"

require_cmd flutter

VERSION_RAW="$(
  grep -E '^[[:space:]]*version:' "$PUBSPEC" | head -n1 |
    awk -F: '{print $2}' | tr -d '[:space:]'
)"
[[ -n "$VERSION_RAW" ]] || die "Could not read version from $PUBSPEC"
VERSION_NAME="${VERSION_RAW%%+*}"
VERSION_BUILD="${VERSION_RAW##*+}"
if [[ "$VERSION_BUILD" == "$VERSION_RAW" ]]; then
  VERSION_BUILD="0"
fi
[[ "$VERSION_NAME" =~ ^[0-9]+([.][0-9]+)*$ ]] ||
  die "Unexpected version format: '$VERSION_RAW' (name='$VERSION_NAME')"

# Carries the build number, as the Windows names do, so two builds of one
# version cannot share a file name.
ARTIFACT_STAMP="Begzar-${VERSION_NAME}+${VERSION_BUILD}-Android"

if [[ "$BUILD_BUNDLE" -eq 1 && "$SPLIT_PER_ABI" -eq 1 ]]; then
  echo -e "${RED}Warning: --split-per-abi applies to APK only; ignored for app bundle${NC}" >&2
  SPLIT_PER_ABI=0
fi

TARGET_PLATFORM=""
if [[ -n "$ONLY_ABI" ]]; then
  [[ "$BUILD_BUNDLE" -eq 0 ]] || die "--abi applies to APK only"
  case "$ONLY_ABI" in
    arm64-v8a) TARGET_PLATFORM="android-arm64" ;;
    armeabi-v7a) TARGET_PLATFORM="android-arm" ;;
    x86_64) TARGET_PLATFORM="android-x64" ;;
    *) die "Unknown ABI '$ONLY_ABI' (expected arm64-v8a, armeabi-v7a or x86_64)" ;;
  esac
  # The engine build and verify_engine.sh both narrow to this one ABI.
  export PROXY_ENGINE_ABIS="$ONLY_ABI"
  SPLIT_PER_ABI=1
fi

DEFAULT_SOURCE="github"
if [[ "$BUILD_BUNDLE" -eq 1 ]]; then
  DEFAULT_SOURCE="google_play"
fi
resolve_distribution_source android "$DEFAULT_SOURCE" "$SOURCE_CLI"

ARTIFACT_KIND="APK"
if [[ "$BUILD_BUNDLE" -eq 1 ]]; then
  ARTIFACT_KIND="App Bundle (AAB)"
fi

echo -e "${GREEN}Begzar Android hardened release build${NC}"
echo "Version: $VERSION_NAME+$VERSION_BUILD (from $VERSION_RAW)"
echo "Source:  $DISTRIBUTION_SOURCE_VALUE"
echo "Output:  $ARTIFACT_KIND"
echo "Root:    $ROOT"
echo "Security: R8 shrink + Dart obfuscate + native strip + split debug-info"

mkdir -p "$DIST_DIR" "$DEBUG_INFO_DIR"

step "Verifying release hardening configuration"
verify_android_release_signing "$ROOT"
verify_android_r8_enabled "$ROOT"
verify_native_security_cmake "$ROOT"

if [[ "$SKIP_BEGZAR" -eq 0 ]]; then
  # Symbols are stripped at link time (-ldflags "-s -w" in build_android.sh).
  step "Building begzar_engine Android native libraries (strip + trimpath)"
  require_cmd go
  bash "$ROOT/begzar-engine/scripts/build_android.sh"
else
  step "Skipping begzar_engine build (--skip-begzar)"
fi

# --skip-begzar is the easy way to reach a release build with no engine on disk.
# Refuse before Flutter packages one rather than after.
# pubspec.yaml depends on the open stand-in; a release is built on the private
# engine, which an uncommitted pubspec_overrides.yaml chooses.
step "Choosing the private engine"
bash "$ROOT/scripts/use_engine.sh" private --no-pub-get

step "Verifying the proxy engine is present"
bash "$ROOT/scripts/verify_engine.sh" check android

if [[ "$SKIP_FLUTTER" -eq 0 ]]; then
  if [[ "$NO_CLEAN" -eq 0 ]]; then
    step "flutter clean (fresh release tree)"
    flutter clean
  fi

  step "flutter pub get"
  flutter pub get

  if [[ "$BUILD_BUNDLE" -eq 1 ]]; then
    BUILD_ARGS=(
      build appbundle
      --release
      --obfuscate
      --split-debug-info="$DEBUG_INFO_DIR"
      --tree-shake-icons
      --dart-define=FLUTTER_BUILD_MODE=release
      --dart-define=DISTRIBUTION_SOURCE="$DISTRIBUTION_SOURCE_VALUE"
    )
  else
    BUILD_ARGS=(
      build apk
      --release
      --obfuscate
      --split-debug-info="$DEBUG_INFO_DIR"
      --tree-shake-icons
      --dart-define=FLUTTER_BUILD_MODE=release
      --dart-define=DISTRIBUTION_SOURCE="$DISTRIBUTION_SOURCE_VALUE"
    )
    if [[ "$SPLIT_PER_ABI" -eq 1 ]]; then
      BUILD_ARGS+=(--split-per-abi)
    fi
    if [[ -n "$TARGET_PLATFORM" ]]; then
      BUILD_ARGS+=(--target-platform="$TARGET_PLATFORM")
    fi
  fi

  step "flutter ${BUILD_ARGS[*]}"
  # The engine was built (or, with --skip-begzar, kept) and checked above. Tell
  # Gradle's buildProxyEngine not to build it a second time.
  PROXY_ENGINE_PREBUILT=1 flutter "${BUILD_ARGS[@]}"

  step "Verifying Dart obfuscation symbols"
  verify_obfuscation_symbols "$DEBUG_INFO_DIR"
else
  step "Skipping Flutter build (--skip-flutter)"
fi

if [[ "$BUILD_BUNDLE" -eq 1 ]]; then
  AAB_SRC="$AAB_DIR/app-release.aab"
  [[ -f "$AAB_SRC" ]] || die "Release App Bundle not found: $AAB_SRC"

  step "Copying AAB to dist/ (no debug symbols in artifacts)"
  AAB_DEST="$DIST_DIR/${ARTIFACT_STAMP}.aab"
  cp -f "$AAB_SRC" "$AAB_DEST"
  PRODUCED=("$AAB_DEST")
  echo -e "${GREEN}AAB: $AAB_DEST${NC}"
  ls -lah "$AAB_DEST"
else
  if [[ "$SPLIT_PER_ABI" -eq 1 ]]; then
    shopt -s nullglob
    APKS=("$APK_DIR"/app-*-release.apk)
    shopt -u nullglob
    [[ ${#APKS[@]} -gt 0 ]] || die "Split APKs not found in $APK_DIR"
  else
    APK_SRC="$APK_DIR/app-release.apk"
    [[ -f "$APK_SRC" ]] || die "Release APK not found: $APK_SRC"
    APKS=("$APK_SRC")
  fi

  step "Copying APK(s) to dist/ (no debug symbols in artifacts)"
  PRODUCED=()
  for apk in "${APKS[@]}"; do
    base="$(basename "$apk")"
    if [[ "$base" == "app-release.apk" ]]; then
      dest="$DIST_DIR/${ARTIFACT_STAMP}.apk"
    else
      abi="${base#app-}"
      abi="${abi%-release.apk}"
      dest="$DIST_DIR/${ARTIFACT_STAMP}-${abi}.apk"
    fi
    cp -f "$apk" "$dest"
    PRODUCED+=("$dest")
    echo -e "${GREEN}APK: $dest${NC}"
    ls -lah "$dest"
  done
fi

# The packaged files, not the inputs: Flutter writes the build directory into
# the AOT snapshot, so a release built inside a home folder fails here.
step "Scanning release artifacts for machine identity (account, host, local paths)"
assert_no_machine_identity "Android release artifacts" "$ROOT" "${PRODUCED[@]}"

step "Done"
echo "Artifacts in: $DIST_DIR"
echo "PRIVATE (crash deobfuscation only): $DEBUG_INFO_DIR"
if [[ "$BUILD_BUNDLE" -eq 1 ]]; then
  echo "Never publish debug-info/ or upload-keystore with release AABs."
else
  echo "Never publish debug-info/ or upload-keystore with release APKs."
fi
ls -lah "$DIST_DIR" | sed -n '1,20p'
