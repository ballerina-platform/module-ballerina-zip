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
import ballerina/time;

@test:Config {}
isolated function testRoundTripThroughBothObjects() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");
    string sourceFile = check file:joinPath(work, "hello.txt");
    check io:fileWriteString(sourceFile, "Hello, world!\n");

    ArchiveWriter writer = check new (archivePath);
    check writer.addFile(sourceFile);
    check writer.addEntry("docs/note.txt", "made up\n".toBytes());
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), ["hello.txt", "docs/note.txt"],
            "entries must be listed in the order they were added");
    test:assertEquals(string:fromBytes(check reader.readEntry("hello.txt")), "Hello, world!\n");
    test:assertEquals(string:fromBytes(check reader.readEntry("docs/note.txt")), "made up\n");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddFileNamesTheEntryAfterTheFile() returns error? {
    string work = check file:createTempDir();
    string nested = check file:joinPath(work, "a", "b");
    check file:createDir(nested, file:RECURSIVE);
    string sourceFile = check file:joinPath(nested, "hello.txt");
    check io:fileWriteString(sourceFile, "Hello, world!\n");
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addFile(sourceFile);
    check writer.addFile(sourceFile, "docs/renamed.txt");
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), ["hello.txt", "docs/renamed.txt"],
            "a file with no name given must be stored without the directories above it");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testUnsafeEntryNamesAreRefused() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");
    string sourceFile = check file:joinPath(work, "hello.txt");
    check io:fileWriteString(sourceFile, "Hello, world!\n");
    string[] refused = [
        "/etc/passwd",
        "C:/Windows/x.dll",
        "../evil.txt",
        "docs/../evil.txt",
        "a\\b.txt",
        "docs/./report.txt",
        ""
    ];

    ArchiveWriter writer = check new (archivePath);
    foreach string name in refused {
        Error? added = writer.addFile(sourceFile, name);
        test:assertTrue(added is UnsafePathError,
                string `'${name}' must be refused by addFile rather than corrected`);
        Error? entry = writer.addEntry(name, "content\n".toBytes());
        test:assertTrue(entry is UnsafePathError,
                string `'${name}' must be refused by addEntry rather than corrected`);
    }
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), [], "a refused name must leave nothing in the archive");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddDirectoryIncludesTheSourceDirectory() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addDirectory(tree);
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), [
                "reports/",
                "reports/docs/",
                "reports/docs/report.txt",
                "reports/empty/",
                "reports/summary.txt"
            ]);
    test:assertEquals(string:fromBytes(check reader.readEntry("reports/docs/report.txt")),
            "Quarterly report.\n");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddDirectoryWithoutTheSourceDirectory() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath, {includeSourceDirectory: false});
    check writer.addDirectory(tree);
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), ["docs/", "docs/report.txt", "empty/", "summary.txt"],
            "the contents of the source directory must sit at the top level");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddDirectoryEntryNameOverridesTheSourceDirectoryOption() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath, {includeSourceDirectory: false});
    check writer.addDirectory(tree, "bundle");
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), [
                "bundle/",
                "bundle/docs/",
                "bundle/docs/report.txt",
                "bundle/empty/",
                "bundle/summary.txt"
            ], "a supplied entry name must name the top level even with 'includeSourceDirectory' off");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddDirectoryEntryNameReplacesTheSourceDirectoryName() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addDirectory(tree, "bundle");
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    string[] names = check namesOf(reader);
    test:assertTrue(names.indexOf("bundle/") is int, "the supplied name is the top level");
    test:assertFalse(names.indexOf("reports/") is int, "the source directory name is not used as well");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testUnnamedEmptyDirectoryAddsNothingWithoutTheSourceDirectory() returns error? {
    string work = check file:createTempDir();
    string tree = check file:joinPath(work, "hollow");
    check file:createDir(tree);
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath, {includeSourceDirectory: false});
    check writer.addDirectory(tree);
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), [],
            "a call that names nothing with the option off has no top level to record");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testEmptyDirectoryIsRecordedAsADirectoryEntry() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addDirectory(tree);
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    Entry empty = check reader.getEntry("reports/empty/");
    test:assertTrue(empty.isDirectory);
    test:assertEquals(empty.uncompressedSize, 0);
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testSymbolicLinksAreSkipped() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    check makeSymlink("summary.txt", check file:joinPath(tree, "shortcut.txt"));
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addDirectory(tree);
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    string[] names = check namesOf(reader);
    test:assertFalse(names.indexOf("reports/shortcut.txt") is int,
            "a symbolic link must be neither stored nor followed");
    test:assertTrue(names.indexOf("reports/summary.txt") is int, "the file it points at is stored on its own");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testSourceTimeAndPermissionsAreRecorded() returns error? {
    string work = check file:createTempDir();
    string sourceFile = check file:joinPath(work, "script.sh");
    check io:fileWriteString(sourceFile, "#!/bin/sh\necho hello\n");
    check setMode(sourceFile, "755");
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addFile(sourceFile);
    check writer.close();

    file:MetaData sourceMeta = check file:getMetaData(sourceFile);
    ArchiveReader reader = check new (archivePath);
    Entry script = check reader.getEntry("script.sh");
    test:assertEquals(script.unixMode, 0x1ED, "the permissions of the source must be recorded");
    int drift = script.modifiedTime[0] - sourceMeta.modifiedTime[0];
    test:assertTrue(drift >= -2 && drift <= 2,
            "the time of the entry must be the time of the source, to the two seconds the format stores");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddEntryUsesTheCurrentTime() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");

    [int, decimal] before = time:utcNow();
    ArchiveWriter writer = check new (archivePath);
    check writer.addEntry("note.txt", "made up\n".toBytes());
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    Entry note = check reader.getEntry("note.txt");
    int drift = note.modifiedTime[0] - before[0];
    test:assertTrue(drift >= -2 && drift <= 60, "an entry with no source file must be stamped with the time now");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddEntryFromAStream() returns error? {
    string work = check file:createTempDir();
    string sourceFile = check file:joinPath(work, "big.csv");
    check io:fileWriteString(sourceFile, buildLines());
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    stream<byte[], io:Error?> content = check io:fileReadBlocksAsStream(sourceFile, 1024);
    check writer.addEntry("big.csv", content);
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(string:fromBytes(check reader.readEntry("big.csv")), buildLines());
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressionLevelNoneStoresTheContent() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath, {level: NONE});
    check writer.addEntry("note.txt", buildLines().toBytes());
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    Entry note = check reader.getEntry("note.txt");
    test:assertEquals(note.method, STORE);
    test:assertEquals(note.compressedSize, note.uncompressedSize);
    test:assertEquals(string:fromBytes(check reader.readEntry("note.txt")), buildLines());
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testUseAfterCloseOfAWriter() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");
    string sourceFile = check file:joinPath(work, "hello.txt");
    check io:fileWriteString(sourceFile, "Hello, world!\n");

    ArchiveWriter writer = check new (archivePath);
    check writer.close();
    test:assertTrue(writer.addFile(sourceFile) is InvalidArchiveError,
            "using a closed writer must give an InvalidArchiveError");
    test:assertTrue(writer.addEntry("note.txt", "made up\n".toBytes()) is InvalidArchiveError);
    check writer.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAFileAlreadyAtTheTargetIsKept() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");
    check io:fileWriteString(archivePath, "the previous contents\n");

    ArchiveWriter|Error writer = new (archivePath);
    test:assertTrue(writer is FileSystemError, "a file already at the target must not be replaced by default");
    test:assertEquals(check readFile(archivePath), "the previous contents\n", "the file must be left as it was");
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressKeepsAFileAlreadyAtTheTarget() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");
    string sourceFile = check file:joinPath(work, "hello.txt");
    check io:fileWriteString(archivePath, "the previous contents\n");
    check io:fileWriteString(sourceFile, "Hello, world!\n");

    Error? result = compress(sourceFile, archivePath);
    test:assertTrue(result is FileSystemError, "the convenience API must refuse the target too");
    test:assertEquals(check readFile(archivePath), "the previous contents\n");

    check compress(sourceFile, archivePath, {overwrite: true});
    ArchiveReader reader = check new (archivePath);
    test:assertEquals((check reader.entries()).length(), 1, "'overwrite' must let the archive be written");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testTheTargetIsTruncatedWhenTheWriterIsCreated() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");
    check io:fileWriteString(archivePath, "the previous contents\n");

    ArchiveWriter writer = check new (archivePath, {overwrite: true});
    Error? added = writer.addFile(check file:joinPath(work, "nowhere.txt"));
    test:assertTrue(added is FileSystemError, "adding a file that is not there must fail");
    // The writer is abandoned here without being closed, as a caller meeting that error might.

    file:MetaData left = check file:getMetaData(archivePath);
    test:assertEquals(left.size, 0, "what was at the path must be gone, since the file is truncated on creation");
    ArchiveReader|Error reopened = new (archivePath);
    test:assertTrue(reopened is InvalidArchiveError,
            "a writer that never reached close must leave behind a file that is not a valid archive");
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddEntryOfADirectoryName() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addEntry("empty/", []);
    Error? withContent = writer.addEntry("docs/", "content\n".toBytes());
    test:assertTrue(withContent is Error, "a directory entry given content must be refused, not written");
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    Entry empty = check reader.getEntry("empty/");
    test:assertTrue(empty.isDirectory, "a name ending in '/' with no content records an empty directory");
    test:assertEquals(empty.uncompressedSize, 0);
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testAddEntryOfADirectoryNameFromAStream() returns error? {
    string work = check file:createTempDir();
    string sourceFile = check file:joinPath(work, "content.txt");
    check io:fileWriteString(sourceFile, "content\n");
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    stream<byte[], io:Error?> content = check io:fileReadBlocksAsStream(sourceFile, 1024);
    Error? withContent = writer.addEntry("docs/", content);
    test:assertTrue(withContent is Error, "a directory entry given content must be refused, not written");
    check writer.addEntry("kept.txt", "kept\n".toBytes());
    check writer.close();

    // The refusal leaves nothing behind: an entry opened before the content was looked at would be
    // committed empty by the finishing of it, which is not what the caller was told happened.
    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), ["kept.txt"], "a refused entry must not be in the archive");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressRefusesATargetLinkedToTheSource() returns error? {
    string work = check file:createTempDir();
    string sourceFile = check file:joinPath(work, "data.txt");
    check io:fileWriteString(sourceFile, "Hello, world!\n");
    // A link standing where the archive would be written, pointing back at the file being archived.
    // Its own name differs from the source, so only what it points at gives it away.
    string archivePath = check file:joinPath(work, "out.zip");
    os:Process link = check os:exec({value: "ln", arguments: ["-s", sourceFile, archivePath]});
    test:assertEquals(check link.waitForExit(), 0, "the test needs a symbolic link to be created");

    Error? result = compress(sourceFile, archivePath);
    test:assertTrue(result is FileSystemError, "an archive written through a link onto its own source must be refused");
    test:assertEquals(check readFile(sourceFile), "Hello, world!\n", "the source must not be truncated");
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressADirectory() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(work, "out.zip");

    check compress(tree, archivePath);

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), [
                "reports/",
                "reports/docs/",
                "reports/docs/report.txt",
                "reports/empty/",
                "reports/summary.txt"
            ]);
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressASingleFile() returns error? {
    string work = check file:createTempDir();
    string sourceFile = check file:joinPath(work, "hello.txt");
    check io:fileWriteString(sourceFile, "Hello, world!\n");
    string archivePath = check file:joinPath(work, "out.zip");

    check compress(sourceFile, archivePath, {includeSourceDirectory: false});

    ArchiveReader reader = check new (archivePath);
    test:assertEquals(check namesOf(reader), ["hello.txt"],
            "a single file gives one entry, whatever 'includeSourceDirectory' says");
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressRefusesATargetInsideTheSource() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(tree, "docs", "out.zip");

    Error? result = compress(tree, archivePath);
    test:assertTrue(result is FileSystemError, "an archive inside the directory being walked must be refused");
    test:assertFalse(check file:test(archivePath, file:EXISTS), "the refusal must come before anything is written");
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressOfAMissingSource() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");

    Error? result = compress(check file:joinPath(work, "nowhere"), archivePath);
    test:assertTrue(result is FileSystemError, "a source that is not there must give a FileSystemError");
    test:assertFalse(check file:test(archivePath, file:EXISTS), "nothing must be written when the source is missing");
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testNamesAreWrittenAsUtf8() returns error? {
    string work = check file:createTempDir();
    string archivePath = check file:joinPath(work, "out.zip");

    ArchiveWriter writer = check new (archivePath);
    check writer.addEntry("café.txt", "no flag\n".toBytes());
    check writer.close();

    ArchiveReader reader = check new (archivePath);
    // A name read back whole is a name written as UTF-8 with the flag set: without the flag the same
    // bytes would be decoded as CP437 and would not come back the way they went in.
    test:assertEquals(check namesOf(reader), ["café.txt"]);
    check reader.close();
    check file:remove(work, file:RECURSIVE);
}

@test:Config {}
isolated function testCompressThenDecompress() returns error? {
    string work = check file:createTempDir();
    string tree = check buildTree(work);
    string archivePath = check file:joinPath(work, "out.zip");
    string target = check file:joinPath(work, "back");

    check compress(tree, archivePath);
    check decompress(archivePath, target);

    test:assertEquals(check readFile(check file:joinPath(target, "reports", "summary.txt")), "Summary.\n");
    test:assertEquals(check readFile(check file:joinPath(target, "reports", "docs", "report.txt")),
            "Quarterly report.\n");
    test:assertTrue(check file:test(check file:joinPath(target, "reports", "empty"), file:IS_DIR),
            "an empty directory must survive the round trip");
    check file:remove(work, file:RECURSIVE);
}

isolated function namesOf(ArchiveReader reader) returns string[]|Error {
    Entry[] entries = check reader.entries();
    return from Entry entry in entries
        select entry.name;
}

// A directory named `reports` holding a file, a directory with a file in it, and an empty directory.
isolated function buildTree(string work) returns string|error {
    string tree = check file:joinPath(work, "reports");
    check file:createDir(tree);
    check io:fileWriteString(check file:joinPath(tree, "summary.txt"), "Summary.\n");
    string docs = check file:joinPath(tree, "docs");
    check file:createDir(docs);
    check io:fileWriteString(check file:joinPath(docs, "report.txt"), "Quarterly report.\n");
    check file:createDir(check file:joinPath(tree, "empty"));
    return tree;
}

isolated function buildLines() returns string {
    string[] lines = [];
    foreach int index in 0 ..< 400 {
        lines.push(string `${index},this line is here to make the content worth compressing`);
    }
    return string:'join("\n", ...lines);
}

isolated function makeSymlink(string target, string linkPath) returns error? {
    os:Process process = check os:exec({value: "ln", arguments: ["-s", target, linkPath]});
    int exit = check process.waitForExit();
    if exit != 0 {
        return error("the symbolic link could not be created");
    }
}

isolated function setMode(string path, string mode) returns error? {
    os:Process process = check os:exec({value: "chmod", arguments: [mode, path]});
    int exit = check process.waitForExit();
    if exit != 0 {
        return error("the permissions of the file could not be set");
    }
}
