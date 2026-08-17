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

@test:Config {}
isolated function testReadEntryAsByteArray() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    byte[] content = check reader.readEntry("hello.txt");
    test:assertEquals(string:fromBytes(content), "Hello, world!\n");
    byte[] stored = check reader.readEntry("stored.txt");
    test:assertEquals(string:fromBytes(stored), "Stored, not compressed.\n");
    check reader.close();
}

@test:Config {}
isolated function testReadEntryAsStream() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    stream<byte[], Error?> chunks = check reader.readEntry("data/big.csv");
    int[] sizes = check from byte[] chunk in chunks
        select chunk.length();
    test:assertEquals(int:sum(...sizes), 81600);
    test:assertTrue(sizes.length() > 1, "an entry larger than one chunk must be read in more than one chunk");
    check reader.close();
}

@test:Config {}
isolated function testTwoStreamsAtOnce() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    stream<byte[], Error?> hello = check reader.readEntry("hello.txt");
    stream<byte[], Error?> report = check reader.readEntry("docs/report.txt");
    record {|byte[] value;|}? helloChunk = check hello.next();
    record {|byte[] value;|}? reportChunk = check report.next();
    test:assertEquals(helloChunk is () ? "" : string:fromBytes(helloChunk.value), "Hello, world!\n");
    test:assertEquals(reportChunk is () ? "" : string:fromBytes(reportChunk.value), "Quarterly report.\n");
    check hello.close();
    check report.close();
    check reader.close();
}

@test:Config {}
isolated function testStreamReadToTheEndNeedsNoClosing() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    stream<byte[], Error?> content = check reader.readEntry("hello.txt");
    record {|byte[] value;|}? first = check content.next();
    test:assertTrue(first !is ());
    test:assertTrue(check content.next() is (), "the stream must end after the content of the entry");
    check content.close();
    check reader.close();
}

@test:Config {}
isolated function testStreamOfAClosedArchive() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    stream<byte[], Error?> content = check reader.readEntry("data/big.csv");
    check reader.close();
    record {|byte[] value;|}|Error? next = content.next();
    test:assertTrue(next is InvalidArchiveError, "reading a stream of a closed archive must give an " +
            "InvalidArchiveError");
}

@test:Config {}
isolated function testReadEntryOfADirectoryGivesNothing() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    byte[] content = check reader.readEntry("docs/");
    test:assertEquals(content.length(), 0);
    check reader.close();
}

@test:Config {}
isolated function testReadEntryOfMissingEntry() returns error? {
    ArchiveReader reader = check new (SIMPLE_ARCHIVE);
    byte[]|Error content = reader.readEntry("nowhere.txt");
    test:assertTrue(content is EntryNotFoundError);
    check reader.close();
}

@test:Config {}
isolated function testReadEntryOfUnsupportedCompressionMethod() returns error? {
    ArchiveReader reader = check new (UNSUPPORTED_ARCHIVE);
    Entry entry = check reader.getEntry("compressed.txt");
    test:assertFalse(entry.isDirectory, "an entry of an unsupported method is still listed");
    test:assertEquals(entry.method, OTHER, "a method the library cannot decompress is listed as OTHER");
    byte[]|Error content = reader.readEntry("compressed.txt");
    if content is UnsupportedEntryError {
        test:assertEquals(content.detail().entryName, "compressed.txt");
    } else {
        test:assertFail("an entry of an unsupported compression method must give an UnsupportedEntryError");
    }
    check reader.close();
}

@test:Config {}
isolated function testReadEntryOfEncryptedEntry() returns error? {
    ArchiveReader reader = check new (ENCRYPTED_ARCHIVE);
    byte[]|Error content = reader.readEntry("secret.txt");
    if content is UnsupportedEntryError {
        test:assertEquals(content.detail().entryName, "secret.txt");
    } else {
        test:assertFail("an encrypted entry must give an UnsupportedEntryError");
    }
    check reader.close();
}

@test:Config {}
isolated function testReadEntryOfDuplicateGivesTheFirst() returns error? {
    ArchiveReader reader = check new (DUPLICATES_ARCHIVE);
    byte[] content = check reader.readEntry("dup.txt");
    test:assertEquals(string:fromBytes(content), "first\n");
    check reader.close();
}
