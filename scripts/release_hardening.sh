#!/usr/bin/env bash
# Shared release hardening helpers (anti-tamper / anti-RE build steps).
# Source from build_*_release.sh and begzar-engine/scripts/build_*.sh — do not
# execute directly.

release_hardening_die() {
  echo -e "${RED:-}Error: $1${NC:-}" >&2
  exit 1
}

# Flutter flags for maximum Dart obfuscation (symbols kept out of artifacts).
# $1 = debug-info dir, $2 = DISTRIBUTION_SOURCE (github, google_play, …).
release_flutter_hardening_args() {
  local debug_info_dir="$1"
  local distribution_source="${2:-github}"
  cat <<EOF
--release
--obfuscate
--split-debug-info=${debug_info_dir}
--tree-shake-icons
--dart-define=FLUTTER_BUILD_MODE=release
--dart-define=DISTRIBUTION_SOURCE=${distribution_source}
EOF
}

# Resolve DISTRIBUTION_SOURCE for --dart-define.
# Sets DISTRIBUTION_SOURCE_VALUE. Args: platform default [cli_source]
# CLI flag wins, then env DISTRIBUTION_SOURCE, then default.
resolve_distribution_source() {
  local platform="$1"
  local default_source="$2"
  local cli_source="${3:-}"
  local resolved="${cli_source:-${DISTRIBUTION_SOURCE:-$default_source}}"
  resolved="$(printf '%s' "$resolved" | tr '[:upper:]' '[:lower:]' | tr '-' '_')"

  case "$resolved" in
    gh) resolved=github ;;
    googleplay|play|play_store) resolved=google_play ;;
    msstore|microsoft_store) resolved=ms_store ;;
    test_flight) resolved=testflight ;;
    appstore) resolved=app_store ;;
  esac

  local -a allowed_list
  case "$platform" in
    android) allowed_list=(github google_play) ;;
    windows) allowed_list=(github ms_store) ;;
    macos) allowed_list=(github testflight app_store) ;;
    ios) allowed_list=(testflight app_store) ;;
    *) release_hardening_die "Unknown platform for distribution source: $platform" ;;
  esac

  local ok=0
  local candidate
  for candidate in "${allowed_list[@]}"; do
    if [[ "$resolved" == "$candidate" ]]; then
      ok=1
      break
    fi
  done
  if [[ "$ok" -ne 1 ]]; then
    release_hardening_die \
      "Invalid DISTRIBUTION_SOURCE '$resolved' for $platform (allowed: ${allowed_list[*]})"
  fi
  DISTRIBUTION_SOURCE_VALUE="$resolved"
}

verify_android_release_signing() {
  local root="$1"
  local key_props="$root/android/key.properties"
  if [[ ! -f "$key_props" ]]; then
    release_hardening_die \
      "Missing $key_props — release APK must be signed (upload keystore)."
  fi
}

verify_android_r8_enabled() {
  local gradle="$1/android/app/build.gradle.kts"
  [[ -f "$gradle" ]] || release_hardening_die "Missing $gradle"
  grep -q 'isMinifyEnabled = true' "$gradle" ||
    release_hardening_die "Release minify (R8) is disabled in build.gradle.kts"
  grep -q 'isShrinkResources = true' "$gradle" ||
    release_hardening_die "Release shrinkResources is disabled in build.gradle.kts"
}

verify_native_security_cmake() {
  local cmake="$1/android/app/src/main/cpp/CMakeLists.txt"
  [[ -f "$cmake" ]] || return 0
  grep -q 'fvisibility=hidden' "$cmake" ||
    echo "Warning: native -fvisibility=hidden not found in CMakeLists.txt" >&2
}

verify_obfuscation_symbols() {
  local symbols_dir="$1"
  if [[ ! -d "$symbols_dir" ]] || [[ -z "$(ls -A "$symbols_dir" 2>/dev/null || true)" ]]; then
    release_hardening_die \
      "Obfuscation debug symbols missing in $symbols_dir (build may not be obfuscated)."
  fi
}

assert_no_debug_symbols_in_tree() {
  local dir="$1"
  local label="$2"
  if find "$dir" -type f \( -name '*.pdb' -o -name '*.dSYM' -o -name '*.dbg' \) \
    ! -path '*/Frameworks/*' 2>/dev/null | grep -q .; then
    release_hardening_die \
      "Debug symbols ($label) found in release tree — remove before packaging."
  fi
}

strip_macos_release_binary() {
  local bin_path="$1"
  [[ -f "$bin_path" ]] || return 0
  if command -v strip >/dev/null 2>&1; then
    strip -x "$bin_path" 2>/dev/null || true
  fi
}

remove_macos_dsym_from_app() {
  local app_path="$1"
  find "$app_path" -type d -name '*.dSYM' -exec rm -rf {} + 2>/dev/null || true
}

# Refuse artifacts that name the machine that built them: its account, full
# name, host names, git identity, home or toolchain paths. Every probe is read
# from this machine and no value is ever printed (scripts/identity_scan.py).
# On a CI runner findings are warnings, because the account is the runner's.
# Args: label root path...
assert_no_machine_identity() {
  local label="$1"
  local root="$2"
  shift 2
  command -v python3 >/dev/null 2>&1 ||
    release_hardening_die "python3 is required for the machine identity scan."
  python3 "$root/scripts/identity_scan.py" --label "$label" --repo-root "$root" "$@" ||
    release_hardening_die "Refusing to ship $label: it carries this machine's identity (see above)."
}

purge_windows_debug_artifacts() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  find "$dir" -type f \( -name '*.pdb' -o -name '*.ilk' -o -name '*.exp' \) \
    -delete 2>/dev/null || true
}
