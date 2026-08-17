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

import ballerina/file;
import ballerina/test;

@test:Config {}
isolated function testCopyEntryKeepsTheEntryAsItIsStored() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (SIMPLE_ARCHIVE);
    Entry deflated = check sourceArchive.getEntry("hello.txt");
    Entry stored = check sourceArchive.getEntry("stored.txt");
    ArchiveWriter writer = check new (archivePath);
    check writer.copyEntry(sourceArchive, "hello.txt");
    check writer.copyEntry(sourceArchive, "stored.txt");
    check writer.close();
    check sourceArchive.close();

    ArchiveReader reader = check new (archivePath);
    Entry copiedDeflated = check reader.getEntry("hello.txt");
    test:assertEquals(copiedDeflated.method, deflated.method);
    test:assertEquals(copiedDeflated.compressedSize, deflated.compressedSize, "the content must not be recompressed");
    test:assertEquals(copiedDeflated.uncompressedSize, deflated.uncompressedSize);
    test:assertEquals(copiedDeflated.crc32, deflated.crc32);
    test:assertEquals(copiedDeflated.modifiedTime[0], deflated.modifiedTime[0]);
    test:assertEquals(string:fromBytes(check reader.readEntry("hello.txt")), "Hello, world!\n");

    Entry copiedStored = check reader.getEntry("stored.txt");
    test:assertEquals(copiedStored.method, STORE, "a stored entry must not be deflated by the copy");
    test:assertEquals(copiedStored.crc32, stored.crc32);
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCopyEntryIgnoresTheLevelOfTheWriter() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (SIMPLE_ARCHIVE);
    Entry sourceEntry = check sourceArchive.getEntry("data/big.csv");
    ArchiveWriter writer = check new (archivePath, {level: NONE});
    check writer.copyEntry(sourceArchive, "data/big.csv");
    check writer.close();
    check sourceArchive.close();

    ArchiveReader reader = check new (archivePath);
    Entry copied = check reader.getEntry("data/big.csv");
    test:assertEquals(copied.method, DEFLATE, "the entry keeps the method it was stored with");
    test:assertEquals(copied.compressedSize, sourceEntry.compressedSize);
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCopyEntryOfAnEntryThatCannotBeRead() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (UNSUPPORTED_ARCHIVE);
    Entry sourceEntry = check sourceArchive.getEntry("compressed.txt");
    byte[]|Error unreadable = sourceArchive.readEntry("compressed.txt");
    test:assertTrue(unreadable is UnsupportedEntryError,
            "the content of this entry cannot be decompressed by this library");
    ArchiveWriter writer = check new (archivePath);
    check writer.copyEntry(sourceArchive, "compressed.txt");
    check writer.close();
    check sourceArchive.close();

    ArchiveReader reader = check new (archivePath);
    Entry copied = check reader.getEntry("compressed.txt");
    test:assertEquals(copied.crc32, sourceEntry.crc32, "the copy holds the same bytes, never having decoded them");
    test:assertEquals(copied.compressedSize, sourceEntry.compressedSize);
    byte[]|Error copiedContent = reader.readEntry("compressed.txt");
    test:assertTrue(copiedContent is UnsupportedEntryError,
            "the copy is still an entry this library cannot decompress");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCopyEntryOfAnEncryptedEntry() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (ENCRYPTED_ARCHIVE);
    ArchiveWriter writer = check new (archivePath);
    // The one entry a copy cannot carry: the bytes would go across untouched, but the flag saying
    // they are encrypted would not, leaving a header that says the content is plain when it is not.
    Error? copied = writer.copyEntry(sourceArchive, "secret.txt");
    if copied is UnsupportedEntryError {
        test:assertEquals(copied.detail().entryName, "secret.txt");
    } else {
        test:assertFail("copying an encrypted entry must give an UnsupportedEntryError");
    }
    check writer.close();
    check sourceArchive.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCopyEntryOfADuplicateTakesTheFirst() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (DUPLICATES_ARCHIVE);
    ArchiveWriter writer = check new (archivePath);
    check writer.copyEntry(sourceArchive, "dup.txt");
    check writer.close();
    check sourceArchive.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(string:fromBytes(check reader.readEntry("dup.txt")), "first\n",
            "the first entry with the name is the one copied, as it is the one read");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCopyEntryOfAMissingEntry() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (SIMPLE_ARCHIVE);
    ArchiveWriter writer = check new (archivePath);
    test:assertTrue(writer.copyEntry(sourceArchive, "nowhere.txt") is EntryNotFoundError);
    check writer.close();
    check sourceArchive.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCopyEntryFromAClosedArchive() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (SIMPLE_ARCHIVE);
    check sourceArchive.close();
    ArchiveWriter writer = check new (archivePath);
    test:assertTrue(writer.copyEntry(sourceArchive, "hello.txt") is InvalidArchiveError,
            "the archive an entry is copied from must still be open");
    check writer.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCopyEntryRefusesAnUnsafeName() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (TRAVERSAL_ARCHIVE);
    ArchiveWriter writer = check new (archivePath);
    test:assertTrue(writer.copyEntry(sourceArchive, "../evil.txt") is UnsafePathError,
            "a name this library refuses to extract must not be written by way of a copy");
    check writer.copyEntry(sourceArchive, "ok.txt");
    check writer.close();
    check sourceArchive.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), ["ok.txt"]);
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testRewriteAnArchiveWithoutOneEntry() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "copy.zip");

    ArchiveReader sourceArchive = check new (SIMPLE_ARCHIVE);
    Entry[] entries = check sourceArchive.entries();
    ArchiveWriter writer = check new (archivePath);
    foreach Entry entry in entries {
        if entry.name == "script.sh" {
            continue;
        }
        check writer.copyEntry(sourceArchive, entry.name);
    }
    check writer.close();
    check sourceArchive.close();

    ArchiveReader reader = check new (archivePath);
    string[] names = check namesOf(reader);
    test:assertEquals(names, ["hello.txt", "docs/", "docs/report.txt", "empty/", "stored.txt", "data/big.csv"],
            "every entry but the dropped one is carried across, in the order it was stored");
    test:assertEquals(string:fromBytes(check reader.readEntry("docs/report.txt")), "Quarterly report.\n");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}
