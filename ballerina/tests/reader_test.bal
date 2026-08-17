// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/test;
import ballerina/time;

// The archives are kept out of `tests/resources` on purpose: everything under it is copied into
// the coverage cache, where JaCoCo opens every ZIP file it finds looking for classes and fails on
// an entry it cannot decompress.
const string ARCHIVES = "tests/archives";
const string SIMPLE_ARCHIVE = ARCHIVES + "/simple.zip";
const string SPECIAL_MODE_ARCHIVE = ARCHIVES + "/special-mode.zip";
const string TRAVERSAL_ARCHIVE = ARCHIVES + "/traversal.zip";
const string ABSOLUTE_ARCHIVE = ARCHIVES + "/absolute.zip";
const string BACKSLASH_ARCHIVE = ARCHIVES + "/backslash.zip";
const string FAT_BACKSLASH_ARCHIVE = ARCHIVES + "/fat-backslash.zip";
const string DOT_SEGMENT_ARCHIVE = ARCHIVES + "/dot-segment.zip";
const string BOMB_ARCHIVE = ARCHIVES + "/bomb.zip";
const string LYING_SIZE_ARCHIVE = ARCHIVES + "/lying-size.zip";
const string LINK_DIRECTORY_ARCHIVE = ARCHIVES + "/link-directory.zip";
const string FILE_THEN_DIRECTORY_ARCHIVE = ARCHIVES + "/file-then-directory.zip";
const string DUPLICATES_ARCHIVE = ARCHIVES + "/duplicates.zip";
const string SYMLINK_ARCHIVE = ARCHIVES + "/symlink.zip";
const string UNSUPPORTED_ARCHIVE = ARCHIVES + "/unsupported.zip";
const string ENCRYPTED_ARCHIVE = ARCHIVES + "/encrypted.zip";
const string CP437_ARCHIVE = ARCHIVES + "/cp437.zip";
const string CP437_TABLE_ARCHIVE = ARCHIVES + "/cp437-table.zip";
const string NOT_AN_ARCHIVE = ARCHIVES + "/not-a-zip.zip";

@test:Config {}
isolated function testEntriesAreListedInStoredOrder() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Entry[] entries = check reader.entries();
    string[] names = from Entry entry in entries
        select entry.name;
    test:assertEquals(names, [
                "hello.txt",
                "docs/",
                "docs/report.txt",
                "empty/",
                "script.sh",
                "stored.txt",
                "data/big.csv"
            ]);
    check reader.close();
}

@test:Config {}
isolated function testEntryMetadata() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Entry hello = check reader.getEntry("hello.txt");
    test:assertFalse(hello.isDirectory);
    test:assertFalse(hello.isSymlink);
    test:assertEquals(hello.uncompressedSize, 14);
    test:assertEquals(hello.method, DEFLATE);
    test:assertEquals(hello.unixMode, 0x1A4); // rw-r--r--
    test:assertTrue(hello.crc32 > 0);
    test:assertTrue(hello.compressedSize > 0);

    Entry stored = check reader.getEntry("stored.txt");
    test:assertEquals(stored.method, STORE);
    test:assertEquals(stored.uncompressedSize, stored.compressedSize);

    Entry directory = check reader.getEntry("docs/");
    test:assertTrue(directory.isDirectory);
    test:assertEquals(directory.uncompressedSize, 0);

    Entry script = check reader.getEntry("script.sh");
    test:assertEquals(script.unixMode, 0x1ED); // rwxr-xr-x
    check reader.close();
}

@test:Config {}
isolated function testModeIsReportedAsRecorded() returns error? {
    ArchiveReader reader = check new (SPECIAL_MODE_ARCHIVE);
    Entry special = check reader.getEntry("special.bin");
    test:assertEquals(special.unixMode, 0xFED, "setuid, setgid and sticky must be reported as recorded");
    check reader.close();
}

@test:Config {}
isolated function testModifiedTimeIsRead() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Entry hello = check reader.getEntry("hello.txt");
    time:Civil civil = time:utcToCivil(hello.modifiedTime);
    test:assertEquals(civil.year, 2026);
    test:assertEquals(civil.month, 8);
    check reader.close();
}

@test:Config {}
isolated function testGetEntryOfMissingEntry() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Entry|Error info = reader.getEntry("nowhere.txt");
    test:assertTrue(info is EntryNotFoundError, "a missing entry must give an EntryNotFoundError");
    check reader.close();
}

@test:Config {}
isolated function testGetEntryOfDuplicateGivesTheFirst() returns error? {
    ArchiveReader reader = check new (DUPLICATES_ARCHIVE);
    Entry[] entries = check reader.entries();
    test:assertEquals(entries.length(), 2, "both duplicates must be listed");
    Entry first = check reader.getEntry("dup.txt");
    test:assertEquals(first.uncompressedSize, 6, "the first entry with the name must be the one reached");
    check reader.close();
}

@test:Config {}
isolated function testHasEntry() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    test:assertTrue(check reader.hasEntry("hello.txt"));
    test:assertTrue(check reader.hasEntry("docs/"), "a directory entry must be found like any other");
    test:assertFalse(check reader.hasEntry("nowhere.txt"));
    test:assertFalse(check reader.hasEntry("docs"), "names are matched exactly, so the trailing '/' counts");
    check reader.close();
}

@test:Config {}
isolated function testHasEntryOnAClosedArchive() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.close();
    boolean|Error found = reader.hasEntry("hello.txt");
    test:assertTrue(found is InvalidArchiveError, "a closed archive must give an InvalidArchiveError, not false");
}

@test:Config {}
isolated function testNameWithoutTheUtf8FlagIsDecodedAsCp437() returns error? {
    ArchiveReader reader = check new (CP437_ARCHIVE);
    Entry[] entries = check reader.entries();
    test:assertEquals(entries[0].name, "café.txt");
    byte[] content = check reader.readEntry("café.txt");
    test:assertEquals(string:fromBytes(content), "no flag\n");
    check reader.close();
}

@test:Config {}
isolated function testSymlinkEntryIsVisibleWhenListing() returns error? {
    ArchiveReader reader = check new (SYMLINK_ARCHIVE);
    Entry link = check reader.getEntry("link.txt");
    test:assertTrue(link.isSymlink);
    test:assertFalse(link.isDirectory);
    check reader.close();
}

@test:Config {}
isolated function testCloseTwiceIsFine() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.close();
    check reader.close();
}

@test:Config {}
isolated function testUseAfterClose() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.close();
    Entry[]|Error entries = reader.entries();
    test:assertTrue(entries is InvalidArchiveError, "using a closed archive must give an InvalidArchiveError");
    Entry|Error info = reader.getEntry("hello.txt");
    test:assertTrue(info is InvalidArchiveError);
}

@test:Config {}
isolated function testOpenMissingFile() {
    ArchiveReader|Error reader = new (ARCHIVES + "/nowhere.zip");
    test:assertTrue(reader is FileSystemError, "a missing file must give a FileSystemError");
}

@test:Config {}
isolated function testOpenDirectory() {
    ArchiveReader|Error reader = new (ARCHIVES);
    test:assertTrue(reader is FileSystemError, "a directory must give a FileSystemError");
}

@test:Config {}
isolated function testOpenFileThatIsNotAnArchive() {
    ArchiveReader|Error reader = new (NOT_AN_ARCHIVE);
    test:assertTrue(reader is InvalidArchiveError, "a file that is not a ZIP must give an InvalidArchiveError");
}
