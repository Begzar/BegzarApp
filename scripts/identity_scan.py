#!/usr/bin/env python3
"""Fail a build whose output names the machine that built it.

Release binaries, and the engine archives the build scripts produce, must not
carry the builder's account, full name, host name, home directory or any other
local path. Go's -trimpath does not cover everything: gomobile records the
absolute directory of every replaced module, and Flutter writes the build
directory into the AOT snapshot. So the bytes themselves are checked.

Nothing is hardcoded. Every probe is read from the machine running the scan, and
a probe's value is never printed: a finding names where the probe came from
(HOME, AccountName, …), never what it matched, so a log stays clean even when
the scan fails. The Windows release runs the same check from
scripts/ReleaseHardening.ps1.

Usage:
  ./scripts/identity_scan.py [--label TEXT] [--repo-root DIR]
      [--extra-probes FILE] [--allow SOURCE]... PATH...

PATH is a file, a directory (walked recursively) or `-` for standard input. ZIP
files (APKs, app bundles, release ZIPs) are scanned as raw bytes and then member
by member, because compression hides a path from a scan of the archive alone.
--extra-probes reads more values to look for, one per line; --allow drops every
probe read from SOURCE.

Exit status: 0 clean, 1 machine identity found, 2 nothing could be scanned. On a
CI runner every finding is a warning instead: the account there belongs to the
runner, not to a person.
"""

from __future__ import annotations

import argparse
import functools
import io
import os
import re
import shutil
import subprocess
import sys
import zipfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Callable, Iterable, Mapping, TextIO

IDENTITY_KIND = "identity"
PATH_KIND = "path"
ERROR_SEVERITY = "error"
WARNING_SEVERITY = "warning"
EXTRA_PROBE_SOURCE = "ExtraProbe"
REPO_ROOT_SOURCE = "RepoRoot"
STANDARD_INPUT_LOCATION = "<stdin>"

# Shorter values match unrelated bytes in any large binary.
MINIMUM_PROBE_LENGTH = 3

# Bytes of surrounding text printed with a finding, on each side.
CONTEXT_BYTES = 96

# Findings printed per file, probe and encoding; the rest are only counted.
FINDINGS_SHOWN_PER_GROUP = 3

# Paths and names every machine has, which say nothing about whose it is.
NON_IDENTIFYING_PATHS = frozenset(
    {"/tmp", "/var/tmp", "/private/tmp", "/usr", "/usr/local", "/opt", "/opt/homebrew"}
)
NON_IDENTIFYING_VALUES = frozenset({"localhost", "localhost.localdomain", "root"})

# A host left with its bare model name, as macOS can name one, names no one, and
# "mac" is also every MAC in crypto code and every "Mac OS X" in a user agent.
NON_IDENTIFYING_HOST_NAMES = frozenset(
    {"mac", "imac", "macbook", "macbook-air", "macbook-pro", "mac-mini", "mac-studio", "mac-pro"}
)

ENVIRONMENT_IDENTITIES = ("USER", "LOGNAME")
ENVIRONMENT_PATHS = ("HOME", "TMPDIR", "PUB_CACHE", "FLUTTER_ROOT", "ANDROID_HOME", "ANDROID_SDK_ROOT")
GO_PATHS = ("GOPATH", "GOROOT", "GOMODCACHE")
MAC_HOST_NAMES = ("ComputerName", "LocalHostName", "HostName")
GIT_IDENTITY_KEYS = (("GitUserName", "user.name"), ("GitUserEmail", "user.email"))

# A name for each on-disk form a probe is searched in, and Python's codec for it.
ENCODINGS = (("utf8", "utf-8"), ("utf16le", "utf-16-le"))

# A hit must not sit inside a longer identifier, so a short account name does not
# trip on an unrelated word.
TOKEN_CHARACTER = rb"[A-Za-z0-9_]"

ZIP_SIGNATURE = b"PK\x03\x04"

# Flutter records the build directory beside this file in the AOT snapshot and
# has no --trimpath equivalent.
FLUTTER_BUILD_DIRECTORY_MARKER = b"dart_plugin_registrant"
FLUTTER_BUILD_DIRECTORY_NOTE = (
    "Flutter embeds the build directory in the AOT snapshot. "
    "Build on CI or from a neutral directory to keep it anonymous."
)

NON_PRINTABLE = re.compile(r"[^\x20-\x7E]")


@dataclass(frozen=True)
class Probe:
    """One value that would identify the building machine, and where it was read."""

    source: str
    kind: str
    value: str


@dataclass(frozen=True)
class AccountFacts:
    """The local account running the scan, as the system's user database has it."""

    name: str
    full_name: str


@dataclass(frozen=True)
class Finding:
    """A probe found in scanned bytes. The context is redacted before it is kept."""

    location: str
    source: str
    kind: str
    encoding: str
    offset: int
    context: str
    severity: str = ERROR_SEVERITY
    note: str = ""


def run_command(arguments: list[str]) -> str | None:
    """Return a command's trimmed output, or None when it fails or is missing."""
    try:
        completed = subprocess.run(arguments, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    answer = completed.stdout.strip()
    return answer if completed.returncode == 0 and answer else None


def read_account() -> AccountFacts | None:
    try:
        import pwd
    except ImportError:
        return None
    try:
        entry = pwd.getpwuid(os.getuid())
    except KeyError:
        return None
    return AccountFacts(name=entry.pw_name, full_name=entry.pw_gecos.split(",")[0].strip())


def flutter_sdk_root(environment: Mapping[str, str]) -> str | None:
    if "PATH" not in environment:
        return None
    flutter = shutil.which("flutter", path=environment["PATH"])
    if not flutter:
        return None
    return str(Path(flutter).resolve().parent.parent)


def gather_candidates(
    environment: Mapping[str, str],
    repo_root: Path | None,
    run: Callable[[list[str]], str | None],
    account: AccountFacts | None,
) -> list[Probe]:
    """Read every value that could identify this machine, unfiltered.

    `run` answers a command line, or None when the command is missing or fails,
    so a probe a platform does not have (scutil off macOS, git off a checkout)
    is simply absent.
    """
    candidates: list[Probe] = []

    def add(source: str, kind: str, value: str | None) -> None:
        if value:
            candidates.append(Probe(source=source, kind=kind, value=value))

    for name in ENVIRONMENT_IDENTITIES:
        add(name, IDENTITY_KIND, environment.get(name))
    if account:
        add("AccountName", IDENTITY_KIND, account.name)
        add("AccountFullName", IDENTITY_KIND, account.full_name)
    host = run(["hostname"])
    add("HostName", IDENTITY_KIND, host)
    if host:
        add("ShortHostName", IDENTITY_KIND, host.split(".")[0])
    for name in MAC_HOST_NAMES:
        add(name, IDENTITY_KIND, run(["scutil", "--get", name]))
    if repo_root:
        for source, key in GIT_IDENTITY_KEYS:
            add(source, IDENTITY_KIND, run(["git", "-C", str(repo_root), "config", "--get", key]))

    for name in ENVIRONMENT_PATHS:
        add(name, PATH_KIND, environment.get(name))
    add("FlutterSdk", PATH_KIND, flutter_sdk_root(environment))
    for name in GO_PATHS:
        add(name, PATH_KIND, run(["go", "env", name]))
    if repo_root:
        add(REPO_ROOT_SOURCE, PATH_KIND, str(repo_root))
    return candidates


def comparable_value(probe: Probe) -> str:
    key = probe.value.lower()
    return key.replace("\\", "/") if probe.kind == PATH_KIND else key


def is_nested_under(path: Probe, others: Iterable[Probe]) -> bool:
    own = comparable_value(path)
    return any(
        own.startswith(comparable_value(other) + "/") for other in others if other is not path
    )


def normalize_probes(candidates: Iterable[Probe]) -> list[Probe]:
    """Drop values that are too short, shared by every machine, or already covered.

    A path nested under another probed path is covered by its parent: any hit on
    the child is a hit on the parent too.
    """
    kept: list[Probe] = []
    seen: set[str] = set()
    for candidate in candidates:
        value = candidate.value.strip()
        if candidate.kind == PATH_KIND:
            value = value.rstrip("/\\")
        if len(value) < MINIMUM_PROBE_LENGTH:
            continue
        probe = Probe(source=candidate.source, kind=candidate.kind, value=value)
        key = comparable_value(probe)
        if key in seen:
            continue
        if probe.kind == PATH_KIND and key in NON_IDENTIFYING_PATHS:
            continue
        if probe.kind == IDENTITY_KIND and key in NON_IDENTIFYING_VALUES:
            continue
        if probe.kind == IDENTITY_KIND and key in NON_IDENTIFYING_HOST_NAMES:
            continue
        seen.add(key)
        kept.append(probe)
    paths = [probe for probe in kept if probe.kind == PATH_KIND]
    return [
        probe for probe in kept if probe.kind != PATH_KIND or not is_nested_under(probe, paths)
    ]


@functools.lru_cache(maxsize=None)
def probe_pattern(probe: Probe, codec: str) -> bytes:
    """The probe's bytes in `codec`, with either separator allowed inside a path."""
    separator = b"(?:" + re.escape("/".encode(codec)) + b"|" + re.escape("\\".encode(codec)) + b")"
    pieces = []
    for character in probe.value:
        if probe.kind == PATH_KIND and character in "/\\":
            pieces.append(separator)
        else:
            pieces.append(re.escape(character.encode(codec)))
    return b"".join(pieces)


@functools.lru_cache(maxsize=None)
def probe_scanner(probe: Probe, codec: str) -> re.Pattern[bytes]:
    """The probe as a whole token in `codec`, whatever its case."""
    # In UTF-16 a neighbouring letter is followed by its zero byte.
    boundary = TOKEN_CHARACTER + re.escape("a".encode(codec)[1:])
    return re.compile(
        b"(?<!" + boundary + b")" + probe_pattern(probe, codec) + b"(?!" + boundary + b")",
        re.IGNORECASE,
    )


@functools.lru_cache(maxsize=None)
def probe_redactor(probe: Probe) -> re.Pattern[bytes]:
    return re.compile(probe_pattern(probe, "utf-8"), re.IGNORECASE)


def probe_anchor(probe: Probe, codec: str) -> bytes:
    """The probe's longest stretch without a separator, lowercased, in `codec`.

    Every match of the full pattern contains it, and bytes.find runs far faster
    over a whole binary than the pattern does.
    """
    pieces = re.split(r"[/\\]", probe.value) if probe.kind == PATH_KIND else [probe.value]
    return max(pieces, key=len).encode(codec).lower()


def find_matches(data: bytes, lowered: bytes, probe: Probe, codec: str) -> list[re.Match[bytes]]:
    """Every whole-token match of the probe, checked only around its anchor."""
    scanner = probe_scanner(probe, codec)
    anchor = probe_anchor(probe, codec)
    if not anchor:
        return list(scanner.finditer(data))
    # Room for the whole value on either side of the anchor, and one character
    # more so the boundary check after a match sees the real next byte.
    reach = len(probe.value.encode(codec)) + len("a".encode(codec))
    matches: dict[int, re.Match[bytes]] = {}
    position = lowered.find(anchor)
    while position >= 0:
        window_start = max(0, position - reach)
        window_end = min(len(data), position + len(anchor) + reach)
        for match in scanner.finditer(data, window_start, window_end):
            matches[match.start()] = match
        position = lowered.find(anchor, position + 1)
    return list(matches.values())


def redacted_context(data: bytes, start: int, end: int, codec: str, probes: list[Probe]) -> str:
    """The text around a hit, readable, with every probe value replaced by its source.

    The window is read one value's length wider than it is printed and trimmed
    after redaction, so a value the window's edge cuts in half is never printed
    in part. Longer values are replaced first, so a home path reads as [HOME]
    rather than as a path around [USER].
    """
    character_width = len("a".encode(codec))
    longest = max(len(probe.value.encode("utf-8")) for probe in probes)
    reach = (CONTEXT_BYTES + longest) * character_width
    window_start = max(0, start - reach)
    window_end = min(len(data), end + reach)
    window = data[window_start:window_end]
    if character_width > 1:
        window = window.replace(b"\x00", b"")
    for probe in sorted(probes, key=lambda candidate: len(candidate.value), reverse=True):
        window = probe_redactor(probe).sub(b"[" + probe.source.encode("ascii") + b"]", window)
    text = NON_PRINTABLE.sub(".", window.decode("latin-1"))
    leading = longest if window_start > 0 else 0
    trailing = longest if window_end < len(data) else 0
    return text[leading : len(text) - trailing]


def scan_bytes(data: bytes, location: str, probes: list[Probe]) -> list[Finding]:
    lowered = data.lower()
    findings: list[Finding] = []
    for codec_name, codec in ENCODINGS:
        hits = sorted(
            (
                (match, probe)
                for probe in probes
                for match in find_matches(data, lowered, probe, codec)
            ),
            key=lambda hit: (hit[0].start(), -hit[0].end()),
        )
        covered_until = -1
        for match, probe in hits:
            # A home path contains the account name too; the longer hit is reported once.
            if match.start() < covered_until:
                continue
            covered_until = match.end()
            context = redacted_context(data, match.start(), match.end(), codec, probes)
            severity = ERROR_SEVERITY
            note = ""
            nearby = data[max(0, match.start() - CONTEXT_BYTES) : match.end() + CONTEXT_BYTES]
            if probe.source == REPO_ROOT_SOURCE and FLUTTER_BUILD_DIRECTORY_MARKER in nearby:
                # The repository path alone carries no identity: anything personal
                # in it would also have hit an identity or home probe.
                severity = WARNING_SEVERITY
                note = FLUTTER_BUILD_DIRECTORY_NOTE
            findings.append(
                Finding(
                    location=location,
                    source=probe.source,
                    kind=probe.kind,
                    encoding=codec_name,
                    offset=match.start(),
                    context=context,
                    severity=severity,
                    note=note,
                )
            )
    return findings


def scan_archive(data: bytes, location: str, probes: list[Probe]) -> list[Finding]:
    """Scan each member of a ZIP held in `data`, and any ZIP nested inside one."""
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile:
        return []
    findings: list[Finding] = []
    with archive:
        for member in archive.infolist():
            if member.is_dir():
                continue
            member_data = archive.read(member)
            member_location = f"{location}!{member.filename}"
            findings += scan_bytes(member_data, member_location, probes)
            if member_data.startswith(ZIP_SIGNATURE):
                findings += scan_archive(member_data, member_location, probes)
    return findings


def scan_file(path: Path, location: str, probes: list[Probe]) -> list[Finding]:
    data = path.read_bytes()
    findings = scan_bytes(data, location, probes)
    if data.startswith(ZIP_SIGNATURE):
        findings += scan_archive(data, location, probes)
    return findings


def scan_paths(paths: list[Path], probes: list[Probe]) -> list[Finding]:
    """Scan files, and every file under a directory, naming each relative to its root."""
    findings: list[Finding] = []
    for path in paths:
        if path.is_dir():
            for file in sorted(candidate for candidate in path.rglob("*") if candidate.is_file()):
                findings += scan_file(file, file.relative_to(path).as_posix(), probes)
        else:
            findings += scan_file(path, path.name, probes)
    return findings


def load_extra_probes(path: Path) -> list[Probe]:
    probes = []
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if not value or value.startswith("#"):
            continue
        kind = PATH_KIND if value.startswith("/") or ":\\" in value else IDENTITY_KIND
        probes.append(Probe(source=EXTRA_PROBE_SOURCE, kind=kind, value=value))
    return probes


def gather_machine_probes(repo_root: Path | None) -> list[Probe]:
    return gather_candidates(os.environ, repo_root, run_command, read_account())


def report(findings: list[Finding], label: str, on_ci: bool, output: TextIO) -> int:
    """Print the findings, values redacted, and return the exit status."""
    shown: Counter[tuple[str, str, str]] = Counter()
    blocking = 0
    for finding in findings:
        severity = WARNING_SEVERITY if on_ci else finding.severity
        if severity == ERROR_SEVERITY:
            blocking += 1
        group = (finding.location, finding.source, finding.encoding)
        shown[group] += 1
        if shown[group] == 1 and on_ci:
            print(
                f"::{severity}::Machine identity scan ({label}): {finding.location} contains "
                f"{finding.source} ({finding.kind}, {finding.encoding}). {finding.note}".rstrip(),
                file=output,
            )
        if shown[group] > FINDINGS_SHOWN_PER_GROUP:
            continue
        print(
            f"[{severity.upper()}] {finding.location} <- {finding.source} "
            f"({finding.kind}, {finding.encoding} @0x{finding.offset:X}): ...{finding.context}...",
            file=output,
        )
        if finding.note:
            print(f"    {finding.note}", file=output)
    for (location, source, _), count in shown.items():
        if count > FINDINGS_SHOWN_PER_GROUP:
            print(f"    (+{count - FINDINGS_SHOWN_PER_GROUP} more {source} hit(s) in {location})", file=output)

    if blocking:
        print(
            f"Machine identity found in {label} ({blocking} hit(s), see [ERROR] lines above). "
            "Refusing to ship.",
            file=output,
        )
        return 1
    if findings:
        print(f"OK: nothing blocking in {label} ({len(findings)} warning(s) above).", file=output)
    else:
        print(f"OK: no machine identity in {label}.", file=output)
    return 0


def main(
    argv: list[str] | None = None,
    environment: Mapping[str, str] | None = None,
    gather: Callable[[Path | None], list[Probe]] | None = None,
    output: TextIO | None = None,
    standard_input: BinaryIO | None = None,
) -> int:
    parser = argparse.ArgumentParser(
        description="Fail when files carry this machine's account, names or local paths."
    )
    parser.add_argument("paths", nargs="+", metavar="PATH", help="file, directory, or - for stdin")
    parser.add_argument("--label", default="artifacts", help="what is being scanned, for the report")
    parser.add_argument("--repo-root", type=Path, help="checkout whose git identity and path to probe")
    parser.add_argument("--extra-probes", type=Path, help="file of more values, one per line")
    parser.add_argument(
        "--allow", action="append", default=[], metavar="SOURCE", help="ignore probes from SOURCE"
    )
    arguments = parser.parse_args(argv)
    environment = os.environ if environment is None else environment
    gather = gather_machine_probes if gather is None else gather
    output = sys.stdout if output is None else output
    standard_input = sys.stdin.buffer if standard_input is None else standard_input

    candidates = gather(arguments.repo_root)
    if arguments.extra_probes:
        candidates += load_extra_probes(arguments.extra_probes)
    allowed = set(arguments.allow)
    probes = normalize_probes(candidate for candidate in candidates if candidate.source not in allowed)
    if not probes:
        print(f"Machine identity scan ({arguments.label}): no probes could be read.", file=output)
        return 2
    sources = ", ".join(probe.source for probe in probes)
    print(f"Probes ({len(probes)}, values not printed): {sources}", file=output)

    findings: list[Finding] = []
    for path_text in arguments.paths:
        if path_text == "-":
            findings += scan_bytes(standard_input.read(), STANDARD_INPUT_LOCATION, probes)
            continue
        path = Path(path_text)
        if not path.exists():
            print(f"Machine identity scan ({arguments.label}): not found: {path}", file=output)
            return 2
        findings += scan_paths([path], probes)

    on_ci = environment.get("GITHUB_ACTIONS") == "true"
    return report(findings, arguments.label, on_ci, output)


if __name__ == "__main__":
    sys.exit(main())
