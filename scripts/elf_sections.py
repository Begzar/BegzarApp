#!/usr/bin/env python3
"""Fail on native libraries that still carry debug or symbol-table sections.

On Android, Flutter does not pass --strip to gen_snapshot: it leaves stripping
to the Android Gradle plugin, which strips with the NDK's tools. On a machine
without the NDK the plugin packages every library as it is and only warns, so
libapp.so ships with DWARF and a full symbol table. Those carry the app's real
class names, which --obfuscate removes from the code itself.

Section names are read from the ELF section header table rather than searched
for in the file, so a name that appears as ordinary data is not mistaken for a
section.

Usage:
  ./scripts/elf_sections.py LIBRARY...

Prints each library that still carries such sections, with their names. Exit
status: 0 every library is stripped, 1 one is not, 2 a file is not a readable
ELF library.
"""

from __future__ import annotations

import argparse
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, TextIO

ELF_MAGIC = b"\x7fELF"
ELF_CLASS_OFFSET = 4
ELF_BYTE_ORDER_OFFSET = 5

# Sections a stripped library no longer has. .dynsym stays: the loader needs it.
UNSTRIPPED_PREFIXES = (".debug_", ".zdebug_")
UNSTRIPPED_NAMES = frozenset({".symtab", ".gnu_debugdata"})


class NotElfError(ValueError):
    """Raised for a file that is not, or is not entirely, an ELF library."""


@dataclass(frozen=True)
class ElfLayout:
    """Where one ELF class keeps the fields this script reads."""

    section_table_offset_at: int
    section_counts_at: int
    address_format: str
    section_offset_at: int
    section_size_at: int


# Keyed by EI_CLASS: 1 is 32-bit (armeabi-v7a), 2 is 64-bit.
LAYOUTS = {
    1: ElfLayout(
        section_table_offset_at=0x20,
        section_counts_at=0x2E,
        address_format="I",
        section_offset_at=0x10,
        section_size_at=0x14,
    ),
    2: ElfLayout(
        section_table_offset_at=0x28,
        section_counts_at=0x3A,
        address_format="Q",
        section_offset_at=0x18,
        section_size_at=0x20,
    ),
}

# Keyed by EI_DATA: 1 is little-endian, 2 is big-endian.
BYTE_ORDERS = {1: "<", 2: ">"}


def read_name(table: bytes, start: int) -> str:
    end = table.find(b"\x00", start)
    if start > len(table) or end < 0:
        raise NotElfError("a section name points outside the name table")
    return table[start:end].decode("ascii", "replace")


def section_names(data: bytes) -> list[str]:
    """Every section's name, in section header order, the null section first."""
    if not data.startswith(ELF_MAGIC) or len(data) <= ELF_BYTE_ORDER_OFFSET:
        raise NotElfError("not an ELF file")
    layout = LAYOUTS.get(data[ELF_CLASS_OFFSET])
    byte_order = BYTE_ORDERS.get(data[ELF_BYTE_ORDER_OFFSET])
    if layout is None or byte_order is None:
        raise NotElfError("an ELF class or byte order this script does not know")
    address = byte_order + layout.address_format
    try:
        (section_table_offset,) = struct.unpack_from(address, data, layout.section_table_offset_at)
        entry_size, section_count, names_index = struct.unpack_from(
            byte_order + "HHH", data, layout.section_counts_at
        )
        if section_count == 0:
            return []

        def section_field(index: int, field_at: int, field_format: str) -> int:
            (value,) = struct.unpack_from(
                field_format, data, section_table_offset + index * entry_size + field_at
            )
            return value

        names_offset = section_field(names_index, layout.section_offset_at, address)
        names_size = section_field(names_index, layout.section_size_at, address)
        name_table = data[names_offset : names_offset + names_size]
        if len(name_table) != names_size:
            raise NotElfError("the section name table runs past the end of the file")
        return [
            read_name(name_table, section_field(index, 0, byte_order + "I"))
            for index in range(section_count)
        ]
    except struct.error as error:
        raise NotElfError(f"truncated ELF file ({error})") from error


def unstripped_sections(names: Iterable[str]) -> list[str]:
    return [
        name for name in names if name.startswith(UNSTRIPPED_PREFIXES) or name in UNSTRIPPED_NAMES
    ]


def main(argv: list[str] | None = None, output: TextIO | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fail on native libraries that still carry debug or symbol-table sections."
    )
    parser.add_argument("libraries", nargs="+", metavar="LIBRARY")
    arguments = parser.parse_args(argv)
    output = sys.stdout if output is None else output

    status = 0
    for library in arguments.libraries:
        try:
            names = section_names(Path(library).read_bytes())
        except (OSError, NotElfError) as error:
            print(f"{library}: {error}", file=output)
            return 2
        left = unstripped_sections(names)
        if left:
            print(f"{library}: {' '.join(left)}", file=output)
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main())
