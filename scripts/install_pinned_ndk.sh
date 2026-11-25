#!/usr/bin/env bash
# Installs the NDK version android/app/build.gradle.kts pins and exports it as
# NDK_HOME / ANDROID_NDK_HOME for the rest of the job.
#
# Gradle pins ndkVersion for the CMake/C build while begzar-engine's Go build reads
# NDK_HOME. Installing the one version Gradle already asks for keeps a single NDK
# on a disk-constrained runner and keeps both halves on the same toolchain.
set -euo pipefail

NDK_VERSION="$(sed -nE 's/.*ndkVersion[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
  android/app/build.gradle.kts | head -n1)"
if [[ -z "$NDK_VERSION" ]]; then
  echo "::error::Could not read ndkVersion from android/app/build.gradle.kts"
  exit 1
fi
echo "Gradle pins NDK $NDK_VERSION"

SDKMANAGER="$(command -v sdkmanager || true)"
if [[ -z "$SDKMANAGER" ]]; then
  SDKMANAGER="${ANDROID_HOME:-/usr/local/lib/android/sdk}/cmdline-tools/latest/bin/sdkmanager"
fi
if [[ ! -x "$SDKMANAGER" ]]; then
  echo "::error::sdkmanager not found (looked in PATH and \$ANDROID_HOME/cmdline-tools/latest/bin)"
  exit 1
fi

yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
"$SDKMANAGER" --install "ndk;${NDK_VERSION}"

NDK_PATH="${ANDROID_HOME:-/usr/local/lib/android/sdk}/ndk/${NDK_VERSION}"
test -d "$NDK_PATH"
{
  echo "NDK_HOME=$NDK_PATH"
  echo "ANDROID_NDK_HOME=$NDK_PATH"
} >> "$GITHUB_ENV"
