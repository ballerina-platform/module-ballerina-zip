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
import ballerina/os;
import ballerina/test;

@test:Config {}
isolated function testTraversalOutsideTheTargetDirectory() returns error? {
    string parent = check file:createTempDir();
    string target = check file:joinPath(parent, "out");
    ArchiveReader reader = check new (TRAVERSAL_ARCHIVE);
    Error? result = reader.extractAll(target);
    check reader.close();

    if result is UnsafePathError {
        test:assertEquals(result.detail().entryName, "../evil.txt");
    } else {
        test:assertFail("an entry name holding '..' must give an UnsafePathError");
    }
    test:assertFalse(check file:test(check file:joinPath(parent, "evil.txt"), file:EXISTS),
            "nothing may be written outside the target directory");
    check file:remove(parent, file:RECURSIVE);
}

@test:Config {}
isolated function testAbsoluteEntryName() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (ABSOLUTE_ARCHIVE);
    Error? result = reader.extractAll(target);
    check reader.close();
    if result is UnsafePathError {
        test:assertEquals(result.detail().entryName, "/etc/passwd");
    } else {
        test:assertFail("an absolute entry name must give an UnsafePathError");
    }
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testBackslashInEntryName() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (BACKSLASH_ARCHIVE);
    Error? result = reader.extractAll(target);
    check reader.close();
    if result is UnsafePathError {
        test:assertEquals(result.detail().entryName, "a\\b.txt");
    } else {
        test:assertFail("an entry name holding a backslash must give an UnsafePathError");
    }
    test:assertFalse(check file:test(check file:joinPath(target, "a\\b.txt"), file:EXISTS));
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testBackslashInAnEntryNameWrittenOnWindows() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (FAT_BACKSLASH_ARCHIVE);
    // The entry is recorded as made on a FAT platform, where the ZIP implementation underneath hands
    // out 'a/b.txt' for it: the name of a valid path of two parts, rather than the one name section
    // 8.1 requires to be refused. The name has to be read from the bytes as they are stored.
    Entry[] entries = check reader.entries();
    test:assertEquals(entries[0].name, "a\\b.txt", "the name must be read as it is stored");

    Error? result = reader.extractAll(target);
    check reader.close();
    if result is UnsafePathError {
        test:assertEquals(result.detail().entryName, "a\\b.txt");
    } else {
        test:assertFail("a backslash in a name written on Windows must give an UnsafePathError");
    }
    test:assertFalse(check file:test(check file:joinPath(target, "a"), file:EXISTS),
            "the name must not be turned into a path of two parts");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testDotSegmentInEntryName() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (DOT_SEGMENT_ARCHIVE);
    Error? result = reader.extractAll(target);
    check reader.close();
    test:assertTrue(result is UnsafePathError, "an entry name holding a '.' part must give an UnsafePathError");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testSymlinkEntryIsNeverExtracted() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SYMLINK_ARCHIVE);
    Error? result = reader.extractAll(target);
    if result is UnsupportedEntryError {
        test:assertEquals(result.detail().entryName, "link.txt");
    } else {
        test:assertFail("an entry marked as a link must give an UnsupportedEntryError");
    }
    test:assertFalse(check file:test(check file:joinPath(target, "link.txt"), file:EXISTS));

    Error? single = reader.extractEntry("link.txt", check file:joinPath(target, "link.txt"));
    test:assertTrue(single is UnsupportedEntryError);
    check reader.close();
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testDirectoryLinkLeadingOutOfTheTargetDirectory() returns error? {
    string target = check file:createTempDir();
    string outside = check file:createTempDir();
    // A link named after a directory of the archive, pointing out of the target directory, is what an
    // entry would be written through if the path were not resolved before writing.
    os:Process link = check os:exec({value: "ln", arguments: ["-s", outside, check file:joinPath(target, "docs")]});
    test:assertEquals(check link.waitForExit(), 0, "the test needs a symbolic link to be created");

    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Error? result = reader.extractAll(target);
    check reader.close();
    test:assertTrue(result is UnsafePathError, "a link leading out of the target directory must give an " +
            "UnsafePathError");
    test:assertFalse(check file:test(check file:joinPath(outside, "report.txt"), file:EXISTS));
    check file:remove(target, file:RECURSIVE);
    check file:remove(outside, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressionRatioLimit() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (BOMB_ARCHIVE);
    Error? result = reader.extractAll(target, {limits: {maxCompressionRatio: 100}});
    if result is LimitExceededError {
        test:assertEquals(result.detail().entryName, "bomb.bin");
    } else {
        test:assertFail("an entry expanding past the ratio limit must give a LimitExceededError");
    }

    // The same entry is extracted once the caller accepts the ratio it has.
    check reader.extractAll(target, {fileWriteMode: REPLACE, limits: {maxCompressionRatio: 2000}});
    file:MetaData bomb = check file:getMetaData(check file:joinPath(target, "bomb.bin"));
    test:assertEquals(bomb.size, 1024 * 1024);
    check reader.close();
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressionRatioLimitOnASingleEntry() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (BOMB_ARCHIVE);
    Error? result = reader.extractEntry("bomb.bin", check file:joinPath(target, "bomb.bin"),
            {limits: {maxCompressionRatio: 100}});
    check reader.close();
    test:assertTrue(result is LimitExceededError, "extracting one entry cannot sidestep the ratio limit");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testNoRatioLimitUnlessOneIsSet() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (BOMB_ARCHIVE);
    check reader.extractAll(target);
    check reader.close();
    file:MetaData bomb = check file:getMetaData(check file:joinPath(target, "bomb.bin"));
    test:assertEquals(bomb.size, 1024 * 1024, "no limit applies unless the caller sets one");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testARatioLargerThanAnySizeIsNoCeiling() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (BOMB_ARCHIVE);
    check reader.extractAll(target, {limits: {maxCompressionRatio: int:MAX_VALUE}});
    check reader.close();
    file:MetaData bomb = check file:getMetaData(check file:joinPath(target, "bomb.bin"));
    test:assertEquals(bomb.size, 1024 * 1024);
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testTheRatioIsMeasuredAgainstTheBytesRead() returns error? {
    ArchiveReader reader = check new (LYING_SIZE_ARCHIVE);
    // The fixture is only worth anything while the size it records is untrue, so that is asserted
    // before the limit is: a ceiling of a hundred times this would clear the megabyte below.
    Entry bomb = check reader.getEntry("bomb.bin");
    test:assertEquals(bomb.compressedSize, 20000, "the fixture must overstate its compressed size");
    test:assertEquals(bomb.uncompressedSize, 1024 * 1024);

    string target = check file:createTempDir();
    Error? result = reader.extractAll(target, {limits: {maxCompressionRatio: 100}});
    check reader.close();
    if result is LimitExceededError {
        test:assertEquals(result.detail().entryName, "bomb.bin");
    } else {
        test:assertFail("an entry whose recorded compressed size is untrue must still meet the ratio limit");
    }
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testDanglingLinkAtTheTargetIsNotWrittenThrough() returns error? {
    string target = check file:createTempDir();
    string outside = check file:createTempDir();
    string escaped = check file:joinPath(outside, "gone.txt");
    // A link whose target does not exist. Nothing is at the path it names, so a check that follows
    // links reports the destination as free and the content is written where the link points.
    os:Process link = check os:exec({value: "ln",
            arguments: ["-s", escaped, check file:joinPath(target, "hello.txt")]});
    test:assertEquals(check link.waitForExit(), 0, "the test needs a symbolic link to be created");

    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Error? result = reader.extractAll(target);
    check reader.close();
    test:assertTrue(result is Error, "a link standing where an entry is to be written must not be followed");
    test:assertFalse(check file:test(escaped, file:EXISTS), "nothing may be written outside the target directory");
    check file:remove(target, file:RECURSIVE);
    check file:remove(outside, file:RECURSIVE);
}

@test:Config {}
isolated function testEntryThatIsBothADirectoryAndALink() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (LINK_DIRECTORY_ARCHIVE);
    Error? all = reader.extractAll(target);
    Error? one = reader.extractEntry("docs/", check file:joinPath(target, "docs"));
    check reader.close();
    // Both ways of extracting refuse it, and neither leaves a directory behind in its place.
    test:assertTrue(all is UnsupportedEntryError, "an entry marked as a link must give an UnsupportedEntryError");
    test:assertTrue(one is UnsupportedEntryError, "extracting the same entry alone must refuse it too");
    test:assertFalse(check file:test(check file:joinPath(target, "docs"), file:EXISTS));
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testDirectoryEntryMeetingAFileOfTheSameName() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (FILE_THEN_DIRECTORY_ARCHIVE);
    Error? result = reader.extractAll(target);
    check reader.close();
    test:assertTrue(result is FileSystemError, "a directory entry meeting a file must give a FileSystemError");
    // The file the entry before it wrote is left as it is, rather than being taken for a directory.
    test:assertEquals(check readFile(check file:joinPath(target, "item")), "a file, not a directory\n");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testMaxEntriesLimit() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Error? result = reader.extractAll(target, {limits: {maxEntries: 3}});
    check reader.close();
    if result is LimitExceededError {
        // The directory entry of the archive is counted along with the files.
        test:assertEquals(result.detail().entryName, "empty/");
    } else {
        test:assertFail("more entries than allowed must give a LimitExceededError");
    }
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testMaxTotalSizeLimit() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Error? result = reader.extractAll(target, {limits: {maxTotalSize: 100}});
    check reader.close();
    if result is LimitExceededError {
        test:assertEquals(result.detail().entryName, "data/big.csv");
    } else {
        test:assertFail("writing more bytes than allowed must give a LimitExceededError");
    }
    // The entries before it are written, and the one that would have passed the limit is not.
    test:assertEquals(check readFile(check file:joinPath(target, "hello.txt")), "Hello, world!\n");
    file:MetaData big = check file:getMetaData(check file:joinPath(target, "data", "big.csv"));
    test:assertTrue(big.size < 100, "no write may take the total past the limit");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testLimitsMustBePositive() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    test:assertTrue(reader.extractAll(target, {limits: {maxEntries: 0}}) is Error);
    test:assertTrue(reader.extractAll(target, {limits: {maxTotalSize: -1}}) is Error);
    test:assertTrue(reader.extractAll(target, {limits: {maxCompressionRatio: 0}}) is Error);
    check reader.close();
    check file:remove(target, file:RECURSIVE);
}
