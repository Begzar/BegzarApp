#!/usr/bin/env bash
#
# The app must build and run without the private engine, on the open stub in
# engine_stub/. This checks that it does:
#
#   1. the stub's models are the engine's, copied by
#      tool/engine_stub/sync_models.py, and it declares the engine's
#      dependencies, so the app resolves to the same versions on either
#      (skipped when the engine is not checked out, as in the open repository);
#   2. the app and its tests analyze clean against the stub;
#   3. the app's tests pass against it.
#
# It leaves the checkout on whichever engine it found it on.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly OVERRIDES=pubspec_overrides.yaml
saved=""
if [[ -f "$OVERRIDES" ]]; then
  saved="$(cat "$OVERRIDES")"
fi
# The lock is put back as it was: resolving on the stub drops the engine's own
# dependencies from it, and resolving them again would move them.
saved_lock="$(mktemp)"
cp pubspec.lock "$saved_lock"

restore() {
  if [[ -n "$saved" ]]; then
    printf '%s\n' "$saved" > "$OVERRIDES"
  else
    rm -f "$OVERRIDES"
  fi
  cp "$saved_lock" pubspec.lock
  rm -f "$saved_lock"
  flutter pub get >/dev/null
}
trap restore EXIT

if [[ -f begzar-engine/pubspec.yaml ]]; then
  # Inside the stub package, so dart format formats the copy for the stub's
  # language version, as it formatted the committed one.
  scratch="engine_stub/.dart_tool/sync_check"
  rm -rf "$scratch"
  mkdir -p "$scratch/models" "$scratch/constants"
  python3 tool/engine_stub/sync_models.py begzar-engine/lib/ "$scratch/"
  dart format "$scratch" >/dev/null
  stale=""
  while IFS= read -r generated; do
    relative="${generated#"$scratch"/}"
    if ! cmp -s "$generated" "engine_stub/lib/$relative"; then
      stale+="  engine_stub/lib/$relative"$'\n'
    fi
  done < <(find "$scratch" -name '*.dart' | sort)
  rm -rf "$scratch"
  if [[ -n "$stale" ]]; then
    printf 'The stub'"'"'s models are not the engine'"'"'s:\n%s\nCopy them again:\n\n' "$stale" >&2
    printf '  python3 tool/engine_stub/sync_models.py begzar-engine/lib/ engine_stub/lib/\n' >&2
    printf '  dart format engine_stub/lib\n' >&2
    exit 1
  fi
  echo "The stub's models are the engine's."

  # The dependencies block of a pubspec, one entry per line, comments dropped.
  dependencies_of() {
    awk '/^dependencies:/ { inside = 1; next }
         /^[^[:space:]#]/ { inside = 0 }
         inside && !/^[[:space:]]*(#|$)/ { sub(/[[:space:]]+$/, ""); print }' "$1"
  }
  if ! diff <(dependencies_of begzar-engine/pubspec.yaml) \
      <(dependencies_of engine_stub/pubspec.yaml) >/dev/null; then
    printf 'The stub'"'"'s dependencies are not the engine'"'"'s; copy them into\n' >&2
    printf 'engine_stub/pubspec.yaml:\n\n' >&2
    diff <(dependencies_of begzar-engine/pubspec.yaml) \
      <(dependencies_of engine_stub/pubspec.yaml) >&2 || true
    exit 1
  fi
  echo "The stub's dependencies are the engine's."
else
  echo "The private engine is not checked out; skipping the model comparison."
fi

scripts/use_engine.sh stub >/dev/null
flutter analyze
flutter test
echo "The app builds and its tests pass without the private engine."
