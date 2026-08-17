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

import ballerina/jballerina.java;

// This is the whole surface the module depends on from the underlying ZIP
// implementation. Everything else - path safety, extraction limits, walking
// directories, mapping errors - stays in Ballerina, so replacing the
// implementation means porting only this file.
//
// Every function here is supported by both Apache Commons Compress and Go's
// archive/zip. Nothing may be added that only one of them can do.

isolated function nativeOpen(string path) returns handle|Error = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

isolated function nativeEntries(handle archive) returns Entry[]|Error = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

isolated function nativeOpenEntry(handle archive, string name) returns handle|Error = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

isolated function nativeReadChunk(handle entryStream, int size) returns byte[]?|Error = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

isolated function nativeCloseEntry(handle entryStream) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

// Writes the content of the entry at `entryIndex` to `targetPath` and returns the number of bytes
// written. The entry is named by its position, so that the caller decides which of two entries with
// the same name is written. Writing stops before `byteLimit` is passed and `BYTES_EXCEEDED` is
// returned instead; a negative `byteLimit` means no ceiling. It also stops, with `RATIO_EXCEEDED`,
// once the entry has produced more than `maxCompressionRatio` bytes for every compressed byte taken
// from the archive; a ratio of zero or less means no ceiling. The ratio is counted there rather than
// here because only the implementation knows how much compressed input an entry has consumed, and
// the size the archive claims for it can be untrue. Passing a ceiling is reported rather than raised
// as an error, so that the `LimitExceededError` and its message stay in Ballerina.
isolated function nativeExtractEntry(handle archive, int entryIndex, string targetPath,
        int byteLimit, int maxCompressionRatio) returns int|Error = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

isolated function nativeCloseArchive(handle archive) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

// Creates the archive file. Unless `overwrite` is set, a file already at the path is left as it is
// and a `FileSystemError` comes back. Whether the path is free is decided by the operation that
// creates the file rather than by a check made before it, so nothing can appear in between.
isolated function nativeCreate(string path, string level, boolean overwrite) returns handle|Error = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

// Writes the content of the file at `sourcePath` under `entryName`, or a directory entry holding
// nothing when the name ends in `/`. The time of the source is recorded with it, and its permissions
// where the platform keeps any. Which files are walked, and which of them are skipped, is decided by
// the caller.
isolated function nativeAddFile(handle writer, string entryName, string sourcePath) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

isolated function nativeStartEntry(handle writer, string entryName) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

isolated function nativeWriteChunk(handle writer, byte[] content) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

isolated function nativeFinishEntry(handle writer) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

// Writes the first entry named `entryName` of `sourceArchive` into the archive being written, exactly
// as it is stored there. The content is never decoded, so an entry this library cannot read is
// carried across all the same, and the compression of the writer does not apply to it.
isolated function nativeCopyEntry(handle writer, handle sourceArchive, string entryName) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

isolated function nativeCloseWriter(handle writer) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;
