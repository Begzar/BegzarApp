#!/usr/bin/env bash
#
# The proxy engine must never be missing from a build that claims to have one.
#
# Every platform links the Go/Xray engine from a generated artifact that is not
# in git. When one of those artifacts is absent the platform build does not
# necessarily fail — Android's, in particular, used to package an APK with no
# engine in it and exit 0. This script is the single place that knows, per
# platform, which artifact must exist, which script produces it, and whether the
# current host is able to produce it.
#
# Usage:
#   verify_engine.sh check   <platform>        artifact present, or fail
#   verify_engine.sh ensure  <platform>        build it first when the host can
#   verify_engine.sh apk     <path.apk>        packaged APK carries the engine,
#                                              every native library stripped
#   verify_engine.sh bundle  <path>            Windows zip or directory does,
#                                              with the tunnel helper and Wintun
#   verify_engine.sh macho   <path>            linked binary carries engine symbols
#
# Platforms: android, ios, macos, windows

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The ABIs Flutter builds for. There is no x86: Flutter has no 32-bit x86
# target, so no APK carries one. PROXY_ENGINE_ABIS narrows it for a build that
# packages fewer, as begzar-engine/scripts/build_android.sh does with the same variable.
# shellcheck disable=SC2206
readonly ANDROID_ABIS=(${PROXY_ENGINE_ABIS:-arm64-v8a armeabi-v7a x86_64})
readonly ANDROID_JNI_DIR="begzar-engine/android/src/main/jniLibs"
readonly ANDROID_LIB_NAME="libbegzar_engine.so"
# The app's minSdk (flutter.minSdkVersion): every Android engine must load there.
# Deliberately not read from build_android.sh, whose API level is what this
# guards; a check that trusted it would move with the mistake it exists to catch.
readonly ANDROID_MIN_SDK=24
readonly WINDOWS_LIB_NAME="libbegzar_engine.dll"
readonly WINDOWS_PLUGIN_ZIP="begzar-engine/windows/libbegzar_engine.zip"
# What the Windows engine archive carries, and so what must land beside
# begzar.exe: the engine, the helper tunnel mode launches through the admin
# prompt, and the Wintun driver the helper opens its adapter with. Wintun's
# licence travels with them but is not checked; an app without it still runs.
readonly WINDOWS_BUNDLE_FILES=("$WINDOWS_LIB_NAME" begzar-tun.exe wintun.dll)
readonly MACOS_XCFRAMEWORK="macos/libbegzar_engine.xcframework"
readonly MACOS_STATIC_LIB="$MACOS_XCFRAMEWORK/macos-arm64_x86_64/libbegzar_engine.a"
readonly IOS_XCFRAMEWORK="ios/BegzarEngineKit.xcframework"

# Proves a statically linked binary actually carries the engine rather than
# merely having been built against it.
#
# The marker is the Go module name, not an exported entry point, because static
# linking turns the engine's globals into local symbols: `nm -gU` on a linked
# binary reports nothing at all, while plain `nm` finds hundreds. Nor can it be
# a C export like BegzarLaunchEngine — macOS links the cgo archive and has it,
# iOS links the gomobile bridge and does not. The module name is in both.
readonly ENGINE_SYMBOL="begzar_engine"

die() {
  printf '\nerror: %s\n\n' "$1" >&2
  exit 1
}

# The ABI an Android engine was actually built for, read from its ELF header:
# EI_CLASS is byte 4 and e_machine bytes 18-19, little-endian.
#
# A library in the wrong ABI folder is worse than a missing one: it packages
# without complaint and then cannot be loaded. The 32-bit slot once held a copy
# of the arm64 binary, and every armeabi-v7a APK shipped an engine that no
# 32-bit process could open.
elf_abi() {
  local class machine
  class="$(od -An -tu1 -j4 -N1 "$1" | tr -d ' \n')"
  machine="$(od -An -tu1 -j18 -N2 "$1" | awk 'NF { print $1 + 256 * $2; exit }')"
  case "$class:$machine" in
    2:183) printf 'arm64-v8a\n' ;;
    1:40)  printf 'armeabi-v7a\n' ;;
    2:62)  printf 'x86_64\n' ;;
    1:3)   printf 'x86\n' ;;
    *)     printf 'an unknown ABI\n' ;;
  esac
}

# The bionic symbol versions an Android engine binds that are newer than
# minSdk, space-separated; nothing when it loads there.
#
# Built against a newer API level, the engine binds libc symbols under versions
# older Androids do not have, and their loader refuses the whole library: at
# API 35 it bound android_get_device_api_level@LIBC_Q, and Android 9 and older
# could not open it on any ABI (#269). Version names sit NUL-separated in the
# library's string table, so they are read from the file itself rather than
# through a readelf the host may not have.
too_new_for_min_sdk() {
  local version api newer=""
  while read -r version; do
    case "$version" in
      LIBC_N) api=24 ;;
      LIBC_O) api=26 ;;
      LIBC_OMR1) api=27 ;;
      LIBC_P) api=28 ;;
      LIBC_Q) api=29 ;;
      LIBC_R) api=30 ;;
      LIBC_S) api=31 ;;
      LIBC_T) api=33 ;;
      LIBC_U) api=34 ;;
      LIBC_V) api=35 ;;
      # Anything this table has not heard of is newer still, or private.
      *) api=999 ;;
    esac
    ((api <= ANDROID_MIN_SDK)) || newer+="${newer:+ }$version"
  done < <(LC_ALL=C tr '\0' '\n' <"$1" | LC_ALL=C grep -a -x -E 'LIBC_[A-Z0-9]+' | sort -u || true)
  [[ -z "$newer" ]] || printf '%s\n' "$newer"
}

# The members of a zip, one per line. unzip where it is installed, bsdtar where
# it is not: MSYS ships the second without the first.
zip_members() {
  if command -v unzip >/dev/null 2>&1; then
    unzip -Z1 "$1"
  elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -tf "$1"
  else
    printf 'neither unzip nor bsdtar is installed to list %s\n' "$1" >&2
    return 1
  fi
}

# Every file name a Windows zip or directory holds, one per line and without
# its directory, so a file is found at any depth: the release zip nests the app
# one folder down. Either separator ends a directory, because Windows
# PowerShell 5.1's Compress-Archive stores entry names with backslashes.
windows_file_names() {
  if [[ -d "$1" ]]; then
    find "$1" -type f | sed 's#.*[/\\]##'
  else
    zip_members "$1" | sed 's#.*[/\\]##'
  fi
}

# The WINDOWS_BUNDLE_FILES a list of file names lacks, comma-separated; nothing
# when it has them all.
windows_files_missing_from() {
  local names="$1" file absent=""
  for file in "${WINDOWS_BUNDLE_FILES[@]}"; do
    grep -qxF "$file" <<<"$names" || absent+="${absent:+, }$file"
  done
  [[ -z "$absent" ]] || printf '%s\n' "$absent"
}

# ── Per-platform facts ──────────────────────────────────────────────────────

engine_artifacts() {
  case "$1" in
    android)
      local abi
      for abi in "${ANDROID_ABIS[@]}"; do
        printf '%s\n' "$ANDROID_JNI_DIR/$abi/$ANDROID_LIB_NAME"
      done
      ;;
    ios)     printf '%s\n' "$IOS_XCFRAMEWORK" ;;
    macos)   printf '%s\n' "$MACOS_STATIC_LIB" ;;
    windows) printf '%s\n' "$WINDOWS_PLUGIN_ZIP" ;;
    *)       die "unknown platform '$1' (expected android, ios, macos or windows)" ;;
  esac
}

# What a developer runs by hand to produce the artifact. Named in every failure
# message, so the fix is never a search.
engine_producer() {
  case "$1" in
    android) printf '%s\n' "begzar-engine/scripts/build_android.sh" ;;
    ios)     printf '%s\n' "begzar-engine/scripts/build_ios_kit.sh" ;;
    macos)   printf '%s\n' "begzar-engine/scripts/build_mac.sh" ;;
    windows) printf '%s\n' "begzar-engine/scripts/build_windows.ps1" ;;
  esac
}

host_is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

# Whether this host could produce the artifact if asked. A Linux CI runner can
# build the Android engine but can never build an Apple one, and saying so up
# front is more useful than a toolchain error three minutes in.
host_can_build() {
  case "$1" in
    android)
      command -v go >/dev/null 2>&1 &&
        [[ -n "${NDK_HOME:-}${ANDROID_NDK_HOME:-}" ]]
      ;;
    macos)
      host_is_macos && command -v go >/dev/null 2>&1 &&
        command -v xcodebuild >/dev/null 2>&1
      ;;
    ios)
      host_is_macos && command -v gomobile >/dev/null 2>&1
      ;;
    windows)
      # Only meaningful from a Windows shell; PowerShell drives the build.
      [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]] &&
        command -v powershell.exe >/dev/null 2>&1
      ;;
  esac
}

why_host_cannot_build() {
  case "$1" in
    android) printf '%s\n' "needs Go and NDK_HOME or ANDROID_NDK_HOME" ;;
    macos)   printf '%s\n' "needs macOS with Go and Xcode" ;;
    ios)     printf '%s\n' "needs macOS with gomobile on PATH" ;;
    windows) printf '%s\n' "needs a Windows host with PowerShell" ;;
  esac
}

# The producer scripts resolve their own paths relative to the working
# directory, not to $0, so they must be invoked from the directory they live in.
build_engine() {
  local platform="$1" producer
  producer="$(engine_producer "$platform")"
  printf 'The %s proxy engine is missing — building it with %s\n' \
    "$platform" "$producer" >&2
  (
    cd "$REPO_ROOT/$(dirname "$producer")"
    case "$platform" in
      windows) powershell.exe -ExecutionPolicy Bypass -File "./$(basename "$producer")" ;;
      *)       bash "./$(basename "$producer")" ;;
    esac
  )
}

# ── Commands ────────────────────────────────────────────────────────────────

# Artifacts the build cannot use: absent ones, on Android an engine built for
# another ABI than the folder it sits in, or one minSdk cannot load, and on
# Windows an archive without the tunnel helper or Wintun, which an archive from
# before tunnel mode lacks. `ensure` rebuilds them all.
missing_artifacts() {
  local platform="$1" artifact abi built newer names absent
  while read -r artifact; do
    if [[ ! -e "$REPO_ROOT/$artifact" ]]; then
      printf '%s\n' "$artifact"
    elif [[ "$platform" == windows ]]; then
      if ! names="$(windows_file_names "$REPO_ROOT/$artifact")"; then
        printf '%s (could not be listed)\n' "$artifact"
        continue
      fi
      absent="$(windows_files_missing_from "$names")"
      [[ -z "$absent" ]] || printf '%s (carries no %s)\n' "$artifact" "$absent"
    elif [[ "$platform" == android ]]; then
      abi="$(basename "$(dirname "$artifact")")"
      built="$(elf_abi "$REPO_ROOT/$artifact")"
      newer="$(too_new_for_min_sdk "$REPO_ROOT/$artifact")"
      if [[ "$built" != "$abi" ]]; then
        printf '%s (built for %s)\n' "$artifact" "$built"
      elif [[ -n "$newer" ]]; then
        printf '%s (binds %s, newer than minSdk %d)\n' "$artifact" "$newer" "$ANDROID_MIN_SDK"
      fi
    fi
  done < <(engine_artifacts "$platform")
}

# The open engine stub (engine_stub/) has the engine's API and none of the
# engine: an app built on it opens and connects nothing. pubspec.yaml depends on
# it, so a checkout builds on it unless pubspec_overrides.yaml names the private
# engine (scripts/use_engine.sh private). That file naming it is what a build
# must have.
private_engine_selected() {
  local overrides="$REPO_ROOT/pubspec_overrides.yaml"
  [[ -f "$overrides" ]] && grep -qE '^[[:space:]]+path:[[:space:]]+\.?/?begzar-engine[[:space:]]*$' "$overrides"
}

refuse_engine_stub() {
  if ! private_engine_selected; then
    die "This checkout builds against the open engine stub, which connects nothing.
Choose the private engine before building:

  scripts/use_engine.sh private"
  fi
}

cmd_check() {
  local platform="${1:?platform required}" missing
  refuse_engine_stub
  missing="$(missing_artifacts "$platform")"
  if [[ -z "$missing" ]]; then
    printf 'Proxy engine present for %s.\n' "$platform"
    return 0
  fi

  die "$(cat <<EOF
The proxy engine is missing or unusable for $platform, so this build would
produce an app that cannot connect:

$(sed 's/^/  /' <<<"$missing")

Build it with:

  $(engine_producer "$platform")
EOF
)"
}

cmd_ensure() {
  local platform="${1:?platform required}"
  refuse_engine_stub
  if [[ -z "$(missing_artifacts "$platform")" ]]; then
    printf 'Proxy engine present for %s.\n' "$platform"
    return 0
  fi

  if host_can_build "$platform"; then
    build_engine "$platform"
    cmd_check "$platform"
    return
  fi

  die "$(cat <<EOF
The proxy engine is missing for $platform and this host cannot build it
($(why_host_cannot_build "$platform")), so the build is stopping rather than
shipping an app that cannot connect.

Run this where the toolchain is available:

  $(engine_producer "$platform")
EOF
)"
}

# Verifies a packaged APK rather than the source tree: every ABI folder the APK
# ships must carry the engine next to the other native libraries, built for
# that ABI and loadable on minSdk, and no native library may still carry its
# symbol table or debug sections.
cmd_apk() {
  local apk="${1:?path to .apk required}" listing abis abi built newer unpacked unstripped
  [[ -f "$apk" ]] || die "no such APK: $apk"

  listing="$(unzip -l "$apk")"
  abis="$(printf '%s\n' "$listing" | sed -nE 's#.*[[:space:]]lib/([^/]+)/.*#\1#p' | sort -u)"
  [[ -n "$abis" ]] || die "$apk contains no native libraries at all"

  # Expanded now, not when the trap fires: by then this function's locals are
  # gone, and set -u would turn the cleanup into a failure.
  unpacked="$(mktemp -d)"
  trap "rm -rf -- '$unpacked'" EXIT

  # Match with a here-string, never `printf | grep -q`: grep exits on the first
  # match, printf then dies of EPIPE, and pipefail reports that as a failure —
  # a green APK would be declared broken. GNU grep exits eagerly enough to hit
  # this every time; BSD grep does not, so it only ever failed on Linux. The
  # same goes for `unzip -p | head`, hence unpacking to a directory.
  for abi in $abis; do
    grep -q "lib/$abi/$ANDROID_LIB_NAME" <<<"$listing" ||
      die "$(basename "$apk") ships lib/$abi without $ANDROID_LIB_NAME — the proxy engine is missing from the APK"
    unzip -q -o "$apk" "lib/$abi/$ANDROID_LIB_NAME" -d "$unpacked" ||
      die "could not read lib/$abi/$ANDROID_LIB_NAME out of $(basename "$apk")"
    built="$(elf_abi "$unpacked/lib/$abi/$ANDROID_LIB_NAME")"
    [[ "$built" == "$abi" ]] ||
      die "$(basename "$apk") ships lib/$abi/$ANDROID_LIB_NAME built for $built, which $abi devices cannot load"
    newer="$(too_new_for_min_sdk "$unpacked/lib/$abi/$ANDROID_LIB_NAME")"
    [[ -z "$newer" ]] ||
      die "$(basename "$apk") ships lib/$abi/$ANDROID_LIB_NAME bound to $newer, newer than minSdk $ANDROID_MIN_SDK, so older Androids cannot load it"
  done

  # Flutter leaves stripping to the Android Gradle plugin, which strips with the
  # NDK and, on a machine without it, packages every library as it is with only
  # a warning. An unstripped libapp.so carries the app's real class names, which
  # --obfuscate removes from the code itself. See scripts/elf_sections.py.
  command -v python3 >/dev/null 2>&1 ||
    die "python3 is required to check that $(basename "$apk")'s native libraries are stripped"
  unzip -q -o "$apk" 'lib/*' -d "$unpacked" ||
    die "could not read the native libraries out of $(basename "$apk")"
  if ! unstripped="$(cd "$unpacked" && python3 "$REPO_ROOT/scripts/elf_sections.py" lib/*/*.so)"; then
    die "$(basename "$apk") ships native libraries that are not stripped, or could not be read:
$unstripped

The Android Gradle plugin strips them with the NDK. Install the NDK that
ndkVersion pins in android/app/build.gradle.kts and build again."
  fi
  printf 'APK carries the engine for: %s\n' "$(printf '%s ' $abis)"
}

# The Windows engine travels as a loose DLL inside the portable zip or the
# installer payload directory, with the tunnel helper and the Wintun driver
# beside it. Without the DLL the app cannot connect at all; without the other
# two, tunnel mode cannot.
cmd_bundle() {
  local target="${1:?path to zip or directory required}" names absent
  [[ -e "$target" ]] || die "no such bundle: $target"
  names="$(windows_file_names "$target")" || die "could not list the files in $target"
  absent="$(windows_files_missing_from "$names")"
  [[ -z "$absent" ]] ||
    die "$target contains no $absent — the proxy engine or its tunnel files are missing from the bundle. Build them with $(engine_producer windows)"
  printf 'Bundle carries %s.\n' "${WINDOWS_BUNDLE_FILES[*]}"
}

# Apple links the engine statically, so there is no file to look for in the
# built app — only symbols in the binary.
cmd_macho() {
  local binary="${1:?path to a linked binary required}" symbols
  [[ -f "$binary" ]] || die "no such binary: $binary"
  command -v nm >/dev/null 2>&1 || die "nm is required to inspect $binary"

  # Plain nm, never -gU: see ENGINE_SYMBOL. Statically linked engine symbols
  # are local, so restricting to global defined symbols finds nothing.
  symbols="$(nm "$binary" 2>/dev/null || true)"
  grep -q "$ENGINE_SYMBOL" <<<"$symbols" ||
    die "$(basename "$binary") exports no $ENGINE_SYMBOL symbol — the proxy engine is not linked in"
  printf '%s carries the engine.\n' "$(basename "$binary")"
}

main() {
  local command="${1:-}"
  shift || true
  case "$command" in
    check)  cmd_check "$@" ;;
    ensure) cmd_ensure "$@" ;;
    apk)    cmd_apk "$@" ;;
    bundle) cmd_bundle "$@" ;;
    macho)  cmd_macho "$@" ;;
    *)      die "usage: $(basename "$0") {check|ensure} <android|ios|macos|windows>
       $(basename "$0") apk <path.apk>
       $(basename "$0") bundle <path-to-zip-or-dir>
       $(basename "$0") macho <path-to-binary>" ;;
  esac
}

main "$@"
