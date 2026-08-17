# Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
#
# WSO2 LLC. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

"""Writes the ZIP files the tests read.

The archives are built by another tool on purpose: they hold entry names, flags and modes that this
library refuses to write itself. Run this script from the directory it sits in to rebuild them:

    python3 generate_fixtures.py
"""

import os
import random
import zipfile

MODIFIED = (2026, 8, 14, 10, 30, 0)

# What `lying-size.zip` records as the compressed size of its bomb. Large enough that a ceiling of a
# hundred times it would clear the megabyte the entry expands to, and small enough to sit inside the
# file, so that the claim is one a reader could believe.
CLAIMED_COMPRESSED_SIZE = 20000


def entry(name, method=zipfile.ZIP_DEFLATED, mode=0o644, kind=0o100000, system=3):
    info = zipfile.ZipInfo(name, MODIFIED)
    info.compress_type = method
    info.create_system = system  # 3 is Unix, where the mode below is recorded; 0 is FAT
    if system == 3:
        info.external_attr = ((kind | mode) << 16) | (0x10 if name.endswith("/") else 0)
    else:
        info.external_attr = 0x10 if name.endswith("/") else 0
    return info


def write(path, build):
    with zipfile.ZipFile(path, "w") as archive:
        build(archive)
    print("wrote", path)


def simple(archive):
    archive.writestr(entry("hello.txt"), "Hello, world!\n")
    archive.writestr(entry("docs/", mode=0o755, kind=0o40000), b"")
    archive.writestr(entry("docs/report.txt"), "Quarterly report.\n")
    archive.writestr(entry("empty/", mode=0o755, kind=0o40000), b"")
    archive.writestr(entry("script.sh", mode=0o755), "#!/bin/sh\necho hello\n")
    archive.writestr(entry("stored.txt", method=zipfile.ZIP_STORED), "Stored, not compressed.\n")
    # Two chunks worth of content that does not compress far, so that reading it as a stream needs
    # more than one read and extracting it stays well inside the default compression ratio.
    source = random.Random(20260814)
    lines = ["%016x,%016x\n" % (source.getrandbits(64), source.getrandbits(64)) for _ in range(2400)]
    archive.writestr(entry("data/big.csv"), "".join(lines))


def special_mode(archive):
    # setuid, setgid and sticky on top of rwxr-xr-x. Section 2.2 asks for a mode to be reported as the
    # archive records it, these three bits included.
    archive.writestr(entry("special.bin", mode=0o7755), "special\n")


def traversal(archive):
    archive.writestr(entry("ok.txt"), "fine\n")
    archive.writestr(entry("../evil.txt"), "escaped\n")


def absolute(archive):
    archive.writestr(entry("/etc/passwd"), "root\n")


def backslash(archive):
    archive.writestr(entry("a\\b.txt"), "windows\n")


def fat_backslash(archive):
    # The same name, recorded as made on a FAT platform, which is what a Windows tool writes. A
    # library reading the decoded name of this entry rather than its raw bytes is handed 'a/b.txt'.
    archive.writestr(entry("a\\b.txt", system=0), "windows\n")


def data_stream(archive):
    # A ':' past the start of the name. On NTFS this names an alternate data stream of 'notes.txt'
    # rather than a file of its own, so section 7.1 refuses the name wherever the ':' sits.
    archive.writestr(entry("notes.txt:evil"), "hidden\n")


def dot_segment(archive):
    archive.writestr(entry("docs/./report.txt"), "dot\n")


def bomb(archive):
    archive.writestr(entry("bomb.bin"), b"\0" * (1024 * 1024))


def lying_size(archive):
    # The same bomb, with the compressed size recorded for it overstated below. The padding entry
    # that follows gives the file room for the size claimed there to fit inside it.
    archive.writestr(entry("bomb.bin"), b"\0" * (1024 * 1024))
    source = random.Random(20260815)
    archive.writestr(entry("padding.bin", method=zipfile.ZIP_STORED),
                     bytes(source.getrandbits(8) for _ in range(64 * 1024)))


def patch_lying_size(path):
    # Overstates the compressed size of `bomb.bin` in the central directory. Nothing in the format
    # makes that number agree with the bytes that are actually there, so a reader working out how far
    # an entry may expand from the size it claims can be told whatever suits the archive. At the
    # value below, a ratio ceiling built from it would be large enough to let the whole bomb through.
    with open(path, "rb") as file:
        content = bytearray(file.read())
    at = content.find(b"PK\x01\x02")
    while at >= 0:
        length = int.from_bytes(content[at + 28:at + 30], "little")
        if bytes(content[at + 46:at + 46 + length]) == b"bomb.bin":
            content[at + 20:at + 24] = CLAIMED_COMPRESSED_SIZE.to_bytes(4, "little")
            break
        at = content.find(b"PK\x01\x02", at + 1)
    else:
        raise SystemExit("expected a central directory record for bomb.bin")
    with open(path, "wb") as file:
        file.write(bytes(content))


def link_directory(archive):
    # An entry that is a directory by its name and a symbolic link by its mode. Section 4.4 refuses
    # every entry marked as a link, whatever else it also claims to be.
    archive.writestr(entry("docs/", mode=0o777, kind=0o120000), "")


def file_then_directory(archive):
    # A file and a directory entry at the same path, in that order, so that the directory meets the
    # file the entry before it has just written.
    archive.writestr(entry("item"), "a file, not a directory\n")
    archive.writestr(entry("item/", mode=0o755, kind=0o40000), b"")


def duplicates(archive):
    archive.writestr(entry("dup.txt"), "first\n")
    archive.writestr(entry("dup.txt"), "second\n")


def symlink(archive):
    archive.writestr(entry("target.txt"), "the real file\n")
    archive.writestr(entry("link.txt", mode=0o777, kind=0o120000), "target.txt")


def unsupported(archive):
    archive.writestr(entry("compressed.txt", method=zipfile.ZIP_BZIP2), "bzip2 is not supported\n")


def encrypted(archive):
    info = entry("secret.txt")
    archive.writestr(info, "not really encrypted\n")


def cp437(archive):
    # The name is written as ASCII so that the UTF-8 flag stays clear, and the bytes are patched
    # afterwards to the CP437 spelling of "cafe" with an acute accent. The patched byte sequence is
    # the same length, so every offset in the archive stays valid.
    archive.writestr(entry("cafX.txt"), "no flag\n")


def cp437_table(archive):
    # Two entries whose names are every byte value the format allows in one, so that the whole CP437
    # table is decoded when the archive is listed. The low half is written as it is, being ASCII; the
    # high half is written as a placeholder of the same length and patched below, so that the UTF-8
    # flag stays clear. A zero byte is left out: it is refused before decoding.
    archive.writestr(entry("".join(chr(value) for value in range(0x01, 0x80))), "low\n")
    archive.writestr(entry("H" * 128), "high\n")


def patch_cp437_table(path):
    with open(path, "rb") as file:
        content = file.read()
    placeholder = b"H" * 128
    if content.count(placeholder) != 2:
        raise SystemExit("expected the placeholder name in the local and the central header")
    content = content.replace(placeholder, bytes(range(0x80, 0x100)))
    with open(path, "wb") as file:
        file.write(content)


def patch_cp437(path):
    with open(path, "rb") as file:
        content = file.read()
    content = content.replace(b"cafX.txt", b"caf\x82.txt")
    with open(path, "wb") as file:
        file.write(content)


def patch_encrypted(path):
    # Sets the encryption bit of the general purpose bit flag of every header, which is what makes an
    # entry unreadable to a library without a password.
    with open(path, "rb") as file:
        content = bytearray(file.read())
    for signature, offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
        at = content.find(signature)
        while at >= 0:
            content[at + offset] |= 0x01
            at = content.find(signature, at + 1)
    with open(path, "wb") as file:
        file.write(bytes(content))


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    write("simple.zip", simple)
    write("special-mode.zip", special_mode)
    write("traversal.zip", traversal)
    write("absolute.zip", absolute)
    write("backslash.zip", backslash)
    write("fat-backslash.zip", fat_backslash)
    write("data-stream.zip", data_stream)
    write("dot-segment.zip", dot_segment)
    write("bomb.zip", bomb)
    write("lying-size.zip", lying_size)
    patch_lying_size("lying-size.zip")
    write("link-directory.zip", link_directory)
    write("file-then-directory.zip", file_then_directory)
    write("duplicates.zip", duplicates)
    write("symlink.zip", symlink)
    write("unsupported.zip", unsupported)
    write("cp437.zip", cp437)
    patch_cp437("cp437.zip")
    write("cp437-table.zip", cp437_table)
    patch_cp437_table("cp437-table.zip")
    write("encrypted.zip", encrypted)
    patch_encrypted("encrypted.zip")
    with open("not-a-zip.zip", "w") as file:
        file.write("This is not a ZIP file.\n")
    print("wrote not-a-zip.zip")


if __name__ == "__main__":
    main()
