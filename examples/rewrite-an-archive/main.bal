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

import ballerina/io;
import ballerina/zip;

const string SOURCE = "./resources/quarterly.zip";
const string TARGET = "./quarterly-final.zip";

const string DROPPED = "drafts/notes.txt";

public function main() returns error? {
    zip:ArchiveReader existing = check new (SOURCE);
    // A ZIP keeps its index at the end of the file, so the archive is written out afresh rather than
    // changed in place. `overwrite` is set only so that the example can be run more than once.
    zip:ArchiveWriter rebuilt = check new (TARGET, {overwrite: true});

    foreach zip:Entry entry in check existing.entries() {
        if entry.name == DROPPED {
            io:println("dropped  ", entry.name);
            continue;
        }
        // Nothing is decompressed and compressed again, so the content, method, timestamp and
        // checksum all survive, and the `level` of this writer does not apply to the entry.
        check rebuilt.copyEntry(existing, entry.name);
        io:println("copied   ", entry.name, method(entry));
    }

    string released = "Released on 2026-08-17.\n";
    check rebuilt.addEntry("reports/release.txt", released.toBytes());
    io:println("added    reports/release.txt");

    // `close` is what writes the index, so a rewrite that fails part way leaves an unreadable file
    // rather than a plausible archive with entries missing. Write to a temporary path and move it
    // into place when the original has to survive a failure.
    check rebuilt.close();
    check existing.close();

    check report();
}

isolated function report() returns error? {
    zip:ArchiveReader reader = check new (TARGET);
    io:println("\n", TARGET, " holds:");
    foreach zip:Entry entry in check reader.entries() {
        io:println("  ", entry.name, method(entry), " crc ", entry.crc32.toHexString());
    }
    io:println("\nstill holds '", DROPPED, "': ", check reader.hasEntry(DROPPED));
    check reader.close();
}

isolated function method(zip:Entry entry) returns string {
    if entry.isDirectory {
        return " (directory)";
    }
    if entry.method == zip:STORE {
        return " (stored)";
    }
    // `copyEntry` can bring across an entry stored by a method this library cannot decompress.
    // `Entry.method` reports those as `zip:OTHER`.
    return entry.method == zip:DEFLATE ? " (deflated)" : " (other)";
}
