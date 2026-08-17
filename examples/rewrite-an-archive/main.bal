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
    // The archive is written out afresh rather than changed in place: a ZIP keeps its index at the
    // end of the file, so an entry cannot be added to or removed from one that is already written.
    // `overwrite` is set only so that the example can be run more than once.
    zip:ArchiveWriter rebuilt = check new (TARGET, {overwrite: true});

    foreach zip:Entry entry in check existing.entries() {
        if entry.name == DROPPED {
            io:println("dropped  ", entry.name);
            continue;
        }
        // The entry is carried across exactly as it is stored. Nothing is decompressed and
        // compressed again, so the content, method, timestamp and checksum all survive, and the
        // `level` of this writer does not apply to it. A name is matched to the first entry that
        // has it, so a malformed archive holding two entries under one name copies the first twice.
        check rebuilt.copyEntry(existing, entry.name);
        io:println("copied   ", entry.name, method(entry));
    }

    string released = "Released on 2026-08-17.\n";
    check rebuilt.addEntry("reports/release.txt", released.toBytes());
    io:println("added    reports/release.txt");

    // The new archive is not a valid ZIP until the writer is closed, which is what writes its index.
    // A rewrite that fails part way therefore leaves an unreadable file rather than a plausible
    // archive with entries missing. Write to a temporary path and move it into place when the
    // original has to survive a failure.
    check rebuilt.close();
    check existing.close();

    check report();
}

// Reads the archive back to show what survived the rewrite.
isolated function report() returns error? {
    zip:ArchiveReader reader = check new (TARGET);
    io:println("\n", TARGET, " holds:");
    foreach zip:Entry entry in check reader.entries() {
        io:println("  ", entry.name, method(entry), " crc ", entry.crc32.toHexString());
    }
    // A name that is no longer there, asked for without going through an error.
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
    // `copyEntry` carries an entry across without reading it, so it can bring over one stored by a
    // method this library cannot decompress. `Entry.method` reports those as `zip:OTHER`.
    return entry.method == zip:DEFLATE ? " (deflated)" : " (other)";
}
