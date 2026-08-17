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

# Represents an existing ZIP archive opened for reading.
#
# ```ballerina
# zip:ArchiveReader archive = check new ("./reports.zip");
# zip:Entry[] entries = check archive.entries();
# check archive.close();
# ```
public isolated class ArchiveReader {

    # Opens an existing ZIP archive. The archive stays open until `close` is called.
    #
    # + path - Path of the ZIP file to open
    # + return - `()` on success, or an error if the file is missing or not a valid archive
    public isolated function init(string path) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Returns the metadata of every entry, in the order stored in the archive.
    #
    # + return - Metadata of every entry, or an error
    public isolated function entries() returns Entry[]|Error {
        // TODO: implement
        return error Error("not implemented");
    }

    # Returns the metadata of a single entry.
    #
    # + name - Name of the entry within the archive
    # + return - Metadata of the entry, or an error if it does not exist
    public isolated function getEntry(string name) returns Entry|Error {
        // TODO: implement
        return error Error("not implemented");
    }

    # Tells whether the archive holds an entry with the given name.
    #
    # + name - Name of the entry within the archive
    # + return - `true` if the archive holds such an entry, or an error
    public isolated function hasEntry(string name) returns boolean|Error {
        // TODO: implement
        return error Error("not implemented");
    }

    # Reads the content of an entry, as a byte array or as a stream of chunks.
    #
    # + name - Name of the entry within the archive
    # + targetType - Type to read the content into
    # + return - Content of the entry, or an error
    public isolated function readEntry(string name,
            typedesc<byte[]|stream<byte[], Error?>> targetType = <>) returns targetType|Error =
    @java:Method {
        'class: "io.ballerina.lib.zip.nativeimpl.Reader"
    } external;

    # Extracts a single entry to the given file path.
    #
    # + name - Name of the entry within the archive
    # + targetPath - Path of the file to write
    # + options - Options controlling how the entry is extracted
    # + return - `()` on success, or an error
    public isolated function extractEntry(string name, string targetPath,
            DecompressOptions options = {}) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Extracts every entry into the given directory.
    #
    # + targetPath - Path of the directory to extract into, created if it is missing
    # + options - Options controlling how the archive is extracted
    # + return - `()` on success, or an error
    public isolated function extractAll(string targetPath, DecompressOptions options = {}) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Closes the archive and releases the underlying file.
    #
    # + return - `()` on success, or an error
    public isolated function close() returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }
}
