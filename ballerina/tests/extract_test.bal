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
import ballerina/io;
import ballerina/os;
import ballerina/test;

@test:Config {}
isolated function testExtractAllRoundTrip() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.extractAll(target);
    check reader.close();

    test:assertEquals(check readFile(check file:joinPath(target, "hello.txt")), "Hello, world!\n");
    test:assertEquals(check readFile(check file:joinPath(target, "docs", "report.txt")),
            "Quarterly report.\n");
    test:assertTrue(check file:test(check file:joinPath(target, "empty"), file:IS_DIR),
            "a directory entry with nothing in it must be created");
    // No entry records the `data` directory, so it comes from the name of the entry inside it.
    test:assertTrue(check file:test(check file:joinPath(target, "data"), file:IS_DIR));
    file:MetaData big = check file:getMetaData(check file:joinPath(target, "data", "big.csv"));
    test:assertEquals(big.size, 81600);
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExtractAllKeepsTheModifiedTime() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Entry hello = check reader.getEntry("hello.txt");
    check reader.extractAll(target);
    check reader.close();

    file:MetaData extracted = check file:getMetaData(check file:joinPath(target, "hello.txt"));
    test:assertEquals(extracted.modifiedTime[0], hello.modifiedTime[0],
            "the time of the extracted file must be the time recorded for the entry");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExtractAllAppliesNoRecordedPermissions() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.extractAll(target);
    check reader.close();

    // Section 4.4: an extracted file gets the permissions the platform gives a new file, whatever the
    // archive records. A new file is never executable, so the recorded `rwxr-xr-x` is not applied.
    test:assertFalse(check isExecutable(check file:joinPath(target, "script.sh")),
            "an entry recorded as executable must not be made executable");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExtractSingleEntry() returns error? {
    string target = check file:createTempDir();
    string destination = check file:joinPath(target, "report.txt");
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.extractEntry("docs/report.txt", destination);
    check reader.close();

    test:assertEquals(check readFile(destination), "Quarterly report.\n");
    test:assertFalse(check file:test(check file:joinPath(target, "docs"), file:EXISTS),
            "extracting one entry must not create the directories of its name");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExtractSingleEntryIntoAMissingDirectory() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Error? result = reader.extractEntry("hello.txt", check file:joinPath(target, "nowhere", "hello.txt"));
    test:assertTrue(result is FileSystemError, "the directory an entry is extracted into must already exist");
    check reader.close();
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExtractMissingEntry() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    Error? result = reader.extractEntry("nowhere.txt", check file:joinPath(target, "nowhere.txt"));
    test:assertTrue(result is EntryNotFoundError);
    check reader.close();
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExtractDirectoryEntry() returns error? {
    string target = check file:createTempDir();
    string destination = check file:joinPath(target, "docs");
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.extractEntry("docs/", destination);
    check reader.close();
    test:assertTrue(check file:test(destination, file:IS_DIR));
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testFailIfExistsIsTheDefault() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (DUPLICATES_ARCHIVE);
    Error? result = reader.extractAll(target);
    test:assertTrue(result is FileSystemError, "the second entry with the same name must stop the extraction");
    test:assertEquals(check readFile(check file:joinPath(target, "dup.txt")), "first\n");
    check reader.close();
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testReplaceLetsTheLastDuplicateWin() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (DUPLICATES_ARCHIVE);
    check reader.extractAll(target, {fileWriteMode: REPLACE});
    check reader.close();
    test:assertEquals(check readFile(check file:joinPath(target, "dup.txt")), "second\n");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testSkipKeepsTheFirstDuplicate() returns error? {
    string target = check file:createTempDir();
    ArchiveReader reader = check new (DUPLICATES_ARCHIVE);
    check reader.extractAll(target, {fileWriteMode: SKIP});
    check reader.close();
    test:assertEquals(check readFile(check file:joinPath(target, "dup.txt")), "first\n");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testSkipLeavesAFileThatIsAlreadyThere() returns error? {
    string target = check file:createTempDir();
    string destination = check file:joinPath(target, "hello.txt");
    check io:fileWriteString(destination, "mine\n");
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.extractAll(target, {fileWriteMode: SKIP});
    check reader.close();
    test:assertEquals(check readFile(destination), "mine\n");
    test:assertEquals(check readFile(check file:joinPath(target, "docs", "report.txt")),
            "Quarterly report.\n", "extraction must carry on with the next entry");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExistingDirectoriesAreReused() returns error? {
    string target = check file:createTempDir();
    check file:createDir(check file:joinPath(target, "docs"));
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.extractAll(target);
    check reader.close();
    test:assertEquals(check readFile(check file:joinPath(target, "docs", "report.txt")),
            "Quarterly report.\n");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testExtractAllCreatesTheTargetDirectory() returns error? {
    string parent = check file:createTempDir();
    string target = check file:joinPath(parent, "one", "two");
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    check reader.extractAll(target);
    check reader.close();
    test:assertEquals(check readFile(check file:joinPath(target, "hello.txt")), "Hello, world!\n");
    check file:remove(parent, file:RECURSIVE);
}

isolated function isExecutable(string path) returns boolean|error {
    os:Process process = check os:exec({value: "test", arguments: ["-x", path]});
    return check process.waitForExit() == 0;
}

// Read as bytes rather than with `io:fileReadString`, which drops the newline a file ends with.
isolated function readFile(string path) returns string|error {
    return string:fromBytes(check io:fileReadBytes(path));
}
