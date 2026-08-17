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
isolated function testListEntries() returns error? {
    Entry[] entries = check listEntries(SIMPLE_ARCHIVE);
    test:assertEquals(entries.length(), 7);
    test:assertEquals(entries[0].name, "hello.txt");
}

@test:Config {}
isolated function testListEntriesOfMissingFile() {
    Entry[]|Error entries = listEntries(ARCHIVES + "/nowhere.zip");
    test:assertTrue(entries is FileSystemError);
}

@test:Config {}
isolated function testDecompress() returns error? {
    string target = check file:createTempDir();
    check decompress(SIMPLE_ARCHIVE, check file:joinPath(target, "out"));
    test:assertEquals(check readFile(check file:joinPath(target, "out", "hello.txt")), "Hello, world!\n");
    check file:remove(target, file:RECURSIVE);
}

@test:Config {}
isolated function testDecompressOfAnUnsafeArchive() returns error? {
    string target = check file:createTempDir();
    Error? result = decompress(TRAVERSAL_ARCHIVE, check file:joinPath(target, "out"));
    test:assertTrue(result is UnsafePathError);
    check file:remove(target, file:RECURSIVE);
}
