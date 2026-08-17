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

isolated function nativeExtractEntry(handle archive, string name, string targetPath) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

isolated function nativeCloseArchive(handle archive) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Reader"
} external;

isolated function nativeCreate(string path, string level) returns handle|Error = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

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

isolated function nativeCopyEntry(handle writer, handle sourceArchive, string entryName) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;

isolated function nativeCloseWriter(handle writer) returns Error? = @java:Method {
    'class: "io.ballerina.lib.zip.nativeimpl.Writer"
} external;
