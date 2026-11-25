"""Tests for scripts/elf_sections.py.

Run from the repository root:
  python3 -m unittest discover -s test/scripts -p '*_test.py'
"""

from __future__ import annotations

import io
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

import elf_sections  # noqa: E402

ELF_HEADER_64 = 64
ELF_HEADER_32 = 52
SECTION_HEADER_64 = 64
SECTION_HEADER_32 = 40
PROGBITS = 1
STRTAB = 3


def build_elf(names: list[str], is_64_bit: bool = True, contents: bytes = b"") -> bytes:
    """A minimal little-endian shared library holding the named sections.

    Every named section points at `contents`, so a test can put bytes that look
    like a section name inside a section's data.
    """
    header_size = ELF_HEADER_64 if is_64_bit else ELF_HEADER_32
    all_names = [*names, ".shstrtab"]
    name_table = b"\x00"
    name_offsets = []
    for name in all_names:
        name_offsets.append(len(name_table))
        name_table += name.encode("ascii") + b"\x00"

    contents_offset = header_size
    name_table_offset = contents_offset + len(contents)
    section_table_offset = name_table_offset + len(name_table)
    section_count = len(all_names) + 1

    def section(name_offset: int, kind: int, offset: int, size: int) -> bytes:
        if is_64_bit:
            return struct.pack("<IIQQQQIIQQ", name_offset, kind, 0, 0, offset, size, 0, 0, 1, 0)
        return struct.pack("<IIIIIIIIII", name_offset, kind, 0, 0, offset, size, 0, 0, 1, 0)

    sections = section(0, 0, 0, 0)
    for name_offset in name_offsets[:-1]:
        sections += section(name_offset, PROGBITS, contents_offset, len(contents))
    sections += section(name_offsets[-1], STRTAB, name_table_offset, len(name_table))

    identification = b"\x7fELF" + bytes([2 if is_64_bit else 1, 1, 1]) + bytes(9)
    if is_64_bit:
        fields = struct.pack(
            "<HHIQQQIHHHHHH", 3, 183, 1, 0, 0, section_table_offset, 0,
            ELF_HEADER_64, 0, 0, SECTION_HEADER_64, section_count, section_count - 1,
        )
    else:
        fields = struct.pack(
            "<HHIIIIIHHHHHH", 3, 40, 1, 0, 0, section_table_offset, 0,
            ELF_HEADER_32, 0, 0, SECTION_HEADER_32, section_count, section_count - 1,
        )
    return identification + fields + contents + name_table + sections


class SectionNamesTest(unittest.TestCase):
    def test_should_read_the_section_names_of_a_64_bit_library(self):
        names = elf_sections.section_names(build_elf([".text", ".dynsym"]))

        self.assertEqual(names, ["", ".text", ".dynsym", ".shstrtab"])

    def test_should_read_the_section_names_of_a_32_bit_library(self):
        names = elf_sections.section_names(build_elf([".text", ".symtab"], is_64_bit=False))

        self.assertEqual(names, ["", ".text", ".symtab", ".shstrtab"])

    def test_should_refuse_a_file_that_is_not_elf(self):
        with self.assertRaises(elf_sections.NotElfError):
            elf_sections.section_names(b"PK\x03\x04 not a library")

    def test_should_refuse_a_truncated_library(self):
        with self.assertRaises(elf_sections.NotElfError):
            elf_sections.section_names(build_elf([".text"])[:70])


class UnstrippedSectionsTest(unittest.TestCase):
    def test_should_name_debug_and_symbol_table_sections(self):
        names = ["", ".text", ".debug_info", ".zdebug_line", ".symtab", ".gnu_debugdata", ".strtab"]

        self.assertEqual(
            elf_sections.unstripped_sections(names),
            [".debug_info", ".zdebug_line", ".symtab", ".gnu_debugdata"],
        )

    def test_should_pass_the_sections_a_stripped_library_keeps(self):
        names = ["", ".dynsym", ".dynstr", ".text", ".rodata", ".shstrtab"]

        self.assertEqual(elf_sections.unstripped_sections(names), [])


class MainTest(unittest.TestCase):
    def run_main(self, libraries: dict[str, bytes]) -> tuple[int, str]:
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            paths = []
            for name, data in libraries.items():
                path = Path(directory) / name
                path.write_bytes(data)
                paths.append(str(path))
            code = elf_sections.main(paths, output=output)
        return code, output.getvalue()

    def test_should_pass_stripped_libraries(self):
        code, output = self.run_main({"libapp.so": build_elf([".text", ".dynsym"])})

        self.assertEqual(code, 0)
        self.assertEqual(output, "")

    def test_should_fail_and_name_what_a_library_still_carries(self):
        code, output = self.run_main(
            {
                "libapp.so": build_elf([".text", ".symtab", ".debug_info"]),
                "libflutter.so": build_elf([".text"]),
            }
        )

        self.assertEqual(code, 1)
        self.assertIn("libapp.so: .symtab .debug_info", output)
        self.assertNotIn("libflutter.so", output)

    def test_should_not_count_a_section_name_found_in_data(self):
        # A library's data can hold any bytes, section names included.
        library = build_elf([".text", ".rodata"], contents=b"\x00.debug_info\x00.symtab\x00")

        code, _ = self.run_main({"libengine.so": library})

        self.assertEqual(code, 0)

    def test_should_stop_on_a_file_that_is_not_elf(self):
        code, output = self.run_main({"libapp.so": b"not a library"})

        self.assertEqual(code, 2)
        self.assertIn("libapp.so", output)


if __name__ == "__main__":
    unittest.main()
