#!/usr/bin/env bash
#
# Chooses which begzar_engine the app builds against.
#
#   scripts/use_engine.sh private   the private engine, the begzar-engine/
#                                   submodule: what every release is built on
#   scripts/use_engine.sh stub      the open stand-in in engine_stub/ (the
#                                   default): the app builds and opens, and
#                                   connects nothing
#
# pubspec.yaml depends on the stub, so a checkout without the private engine
# builds. Choosing the private engine writes pubspec_overrides.yaml, which is
# never committed. The stub declares the engine's dependencies, so the two
# resolve to the same versions and pubspec.lock differs only in the engine's
# own entry while the private engine is chosen: do not commit the lock then.
#
# --no-pub-get only writes the choice, for a caller that resolves packages
# itself or has no Flutter (the engine-only workflow).
#
# A release build refuses anything but the private engine
# (scripts/verify_engine.sh).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

pub_get=1
choice=""
for arg in "$@"; do
  case "$arg" in
    --no-pub-get) pub_get=0 ;;
    stub | private) choice="$arg" ;;
    *) choice="invalid" ;;
  esac
done

case "$choice" in
  private)
    if [[ ! -f begzar-engine/pubspec.yaml ]]; then
      echo "The private engine is not checked out: git submodule update --init" >&2
      exit 1
    fi
    {
      echo "# Written by scripts/use_engine.sh; not committed. Delete it, or run"
      echo "# \`scripts/use_engine.sh stub\`, to build against the open stand-in."
      echo "dependency_overrides:"
      echo "  begzar_engine:"
      echo "    path: begzar-engine"
    } > pubspec_overrides.yaml
    ;;
  stub)
    rm -f pubspec_overrides.yaml
    ;;
  *)
    echo "usage: $(basename "$0") {stub|private} [--no-pub-get]" >&2
    exit 2
    ;;
esac

if [[ "$pub_get" -eq 1 ]]; then
  flutter pub get
fi
