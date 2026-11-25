"""Tests for scripts/identity_scan.py.

Run from the repository root:
  python3 -m unittest discover -s test/scripts -p '*_test.py'

Every probe value here is made up. Nothing in this file may name a real person,
account or machine: keeping exactly that out of the tree is what the scanner is for.
"""

from __future__ import annotations

import io
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

import identity_scan  # noqa: E402
from identity_scan import AccountFacts, Probe  # noqa: E402

SAMPLE_ACCOUNT = Probe(source="AccountName", kind="identity", value="sample-person")
SAMPLE_HOME = Probe(source="HOME", kind="path", value="/Users/sample-person")
SAMPLE_HOST = Probe(source="HostName", kind="identity", value="sample-host")


def sources_and_encodings(findings: list[identity_scan.Finding]) -> list[tuple[str, str]]:
    return [(finding.source, finding.encoding) for finding in findings]


def answer_nothing(arguments: list[str]) -> str | None:
    return None


def gather_nothing(repo_root: Path | None) -> list[Probe]:
    return []


class ScanBytesTest(unittest.TestCase):
    def test_should_find_an_account_name_stored_as_utf8(self):
        findings = identity_scan.scan_bytes(
            b"\x00\x01built by sample-person\x00", "engine.a", [SAMPLE_ACCOUNT]
        )

        self.assertEqual(sources_and_encodings(findings), [("AccountName", "utf8")])

    def test_should_find_an_account_name_stored_as_utf16(self):
        data = "owner=sample-person;".encode("utf-16-le")

        findings = identity_scan.scan_bytes(data, "app.dll", [SAMPLE_ACCOUNT])

        self.assertEqual(sources_and_encodings(findings), [("AccountName", "utf16le")])

    def test_should_match_whatever_the_case(self):
        findings = identity_scan.scan_bytes(b"by SAMPLE-PERSON.", "engine.a", [SAMPLE_ACCOUNT])

        self.assertEqual(len(findings), 1)

    def test_should_not_count_a_probe_inside_a_longer_identifier(self):
        findings = identity_scan.scan_bytes(b"resample-personal", "engine.a", [SAMPLE_ACCOUNT])

        self.assertEqual(findings, [])

    def test_should_match_a_home_path_written_with_backslashes(self):
        findings = identity_scan.scan_bytes(
            b"C:\\Users\\sample-person\\go\\pkg", "engine.a", [SAMPLE_HOME]
        )

        self.assertEqual(sources_and_encodings(findings), [("HOME", "utf8")])

    def test_should_keep_probe_values_out_of_the_reported_context(self):
        findings = identity_scan.scan_bytes(
            b"path=/Users/sample-person/src host=sample-host",
            "engine.a",
            [SAMPLE_HOME, SAMPLE_ACCOUNT, SAMPLE_HOST],
        )

        self.assertEqual(len(findings), 2)
        for finding in findings:
            self.assertNotIn("sample-person", finding.context.lower())
            self.assertNotIn("sample-host", finding.context.lower())
        self.assertIn("[HOME]", findings[0].context)

    def test_should_not_print_part_of_a_value_cut_by_the_context_window(self):
        # The second path starts so that the first hit's widest window ends inside
        # it, leaving a fragment too short to match and so too short to redact.
        filler = b"." * (identity_scan.CONTEXT_BYTES + 8)
        data = b"/Users/sample-person" + filler + b"/Users/sample-person/x"

        findings = identity_scan.scan_bytes(data, "engine.a", [SAMPLE_HOME])

        self.assertNotIn("sampl", findings[0].context.lower())

    def test_should_find_nothing_in_bytes_that_carry_no_probe(self):
        findings = identity_scan.scan_bytes(b"go/pkg/mod/example.com", "engine.a", [SAMPLE_HOME])

        self.assertEqual(findings, [])


class ScanPathsTest(unittest.TestCase):
    def test_should_look_inside_compressed_zip_members(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "app.apk"
            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zip_file:
                zip_file.writestr("lib/arm64-v8a/libapp.so", b"x" * 64 + b"\x00/Users/sample-person/app")

            findings = identity_scan.scan_paths([archive], [SAMPLE_HOME])

        self.assertIn("app.apk!lib/arm64-v8a/libapp.so", [finding.location for finding in findings])

    def test_should_walk_a_directory_and_name_files_relative_to_it(self):
        with tempfile.TemporaryDirectory() as directory:
            nested = Path(directory) / "Frameworks"
            nested.mkdir()
            (nested / "engine.a").write_bytes(b"sample-person")

            findings = identity_scan.scan_paths([Path(directory)], [SAMPLE_ACCOUNT])

        self.assertEqual([finding.location for finding in findings], ["Frameworks/engine.a"])


class NormalizeProbesTest(unittest.TestCase):
    def test_should_drop_values_shorter_than_three_characters(self):
        probes = identity_scan.normalize_probes(
            [Probe(source="USER", kind="identity", value="ab"), SAMPLE_ACCOUNT]
        )

        self.assertEqual(probes, [SAMPLE_ACCOUNT])

    def test_should_drop_a_path_nested_under_another_probed_path(self):
        pub_cache = Probe(source="PUB_CACHE", kind="path", value="/Users/sample-person/.pub-cache")

        probes = identity_scan.normalize_probes([pub_cache, SAMPLE_HOME])

        self.assertEqual(probes, [SAMPLE_HOME])

    def test_should_drop_a_path_every_machine_shares(self):
        shared = Probe(source="TMPDIR", kind="path", value="/tmp/")

        probes = identity_scan.normalize_probes([shared, SAMPLE_HOME])

        self.assertEqual(probes, [SAMPLE_HOME])

    def test_should_drop_a_host_name_that_is_only_a_model_name(self):
        bare = Probe(source="ShortHostName", kind="identity", value="Mac")

        probes = identity_scan.normalize_probes([bare, SAMPLE_HOST])

        self.assertEqual(probes, [SAMPLE_HOST])

    def test_should_keep_a_host_name_that_carries_a_model_name(self):
        named = Probe(source="LocalHostName", kind="identity", value="Samples-Mac-mini")

        probes = identity_scan.normalize_probes([named])

        self.assertEqual(probes, [named])

    def test_should_keep_one_probe_for_a_value_read_from_two_sources(self):
        probes = identity_scan.normalize_probes(
            [SAMPLE_ACCOUNT, Probe(source="USER", kind="identity", value="Sample-Person")]
        )

        self.assertEqual(probes, [SAMPLE_ACCOUNT])


class GatherCandidatesTest(unittest.TestCase):
    def test_should_read_the_account_and_home_from_the_environment(self):
        candidates = identity_scan.gather_candidates(
            {"USER": "sample-person", "HOME": "/Users/sample-person"}, None, answer_nothing, None
        )

        self.assertIn(Probe(source="USER", kind="identity", value="sample-person"), candidates)
        self.assertIn(SAMPLE_HOME, candidates)

    def test_should_read_the_full_name_from_the_account(self):
        candidates = identity_scan.gather_candidates(
            {}, None, answer_nothing, AccountFacts(name="sample-person", full_name="Sample Person")
        )

        self.assertIn(Probe(source="AccountFullName", kind="identity", value="Sample Person"), candidates)

    def test_should_ask_git_for_the_commit_identity(self):
        def answer_git(arguments: list[str]) -> str | None:
            return "Sample Person" if arguments[-1] == "user.name" else None

        candidates = identity_scan.gather_candidates({}, Path("/work/repo"), answer_git, None)

        self.assertIn(Probe(source="GitUserName", kind="identity", value="Sample Person"), candidates)


class MainTest(unittest.TestCase):
    def run_main(
        self,
        arguments: list[str],
        environment: dict[str, str] | None = None,
        standard_input: bytes = b"",
        gather=gather_nothing,
    ):
        output = io.StringIO()
        code = identity_scan.main(
            arguments,
            environment=environment or {},
            gather=gather,
            output=output,
            standard_input=io.BytesIO(standard_input),
        )
        return code, output.getvalue()

    def test_should_fail_without_printing_the_value_it_found(self):
        with tempfile.TemporaryDirectory() as directory:
            probes = Path(directory) / "probes.txt"
            probes.write_text("sample-person\n", encoding="utf-8")
            artifact = Path(directory) / "engine.a"
            artifact.write_bytes(b"built by sample-person")

            code, output = self.run_main(["--extra-probes", str(probes), str(artifact)])

        self.assertEqual(code, 1)
        self.assertIn("ExtraProbe", output)
        self.assertNotIn("sample-person", output.lower())

    def test_should_pass_an_artifact_that_carries_no_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            probes = Path(directory) / "probes.txt"
            probes.write_text("# One value per line.\nsample-person\n", encoding="utf-8")
            artifact = Path(directory) / "engine.a"
            artifact.write_bytes(b"go/pkg/mod")

            code, output = self.run_main(["--extra-probes", str(probes), str(artifact)])

        self.assertEqual(code, 0)
        self.assertIn("OK", output)

    def test_should_warn_instead_of_failing_on_a_ci_runner(self):
        with tempfile.TemporaryDirectory() as directory:
            probes = Path(directory) / "probes.txt"
            probes.write_text("sample-person\n", encoding="utf-8")
            artifact = Path(directory) / "engine.a"
            artifact.write_bytes(b"built by sample-person")

            code, output = self.run_main(
                ["--extra-probes", str(probes), str(artifact)], environment={"GITHUB_ACTIONS": "true"}
            )

        self.assertEqual(code, 0)
        self.assertIn("::warning::", output)

    def test_should_skip_a_probe_source_it_is_told_to_allow(self):
        # A commit's author is the identity a push is meant to carry, so the
        # pre-push check allows the git identity and nothing else.
        code, output = self.run_main(
            ["--allow", "AccountName", "-"],
            standard_input=b"Author: sample-person",
            gather=lambda repo_root: [SAMPLE_ACCOUNT, SAMPLE_HOST],
        )

        self.assertEqual(code, 0)
        self.assertIn("OK", output)

    def test_should_scan_standard_input(self):
        with tempfile.TemporaryDirectory() as directory:
            probes = Path(directory) / "probes.txt"
            probes.write_text("sample-person\n", encoding="utf-8")

            code, output = self.run_main(
                ["--extra-probes", str(probes), "-"], standard_input=b"Author: sample-person"
            )

        self.assertEqual(code, 1)
        self.assertIn("<stdin>", output)

    def test_should_refuse_to_scan_with_no_probes(self):
        code, _ = self.run_main(["-"], standard_input=b"anything")

        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
