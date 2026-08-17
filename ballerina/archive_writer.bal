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

# Represents a new ZIP archive being created. Entries are written in the order
# they are added, and the archive is completed by `close`.
#
# ```ballerina
# zip:ArchiveWriter writer = check new ("./reports.zip");
# check writer.addFile("./summary.pdf");
# check writer.close();
# ```
public isolated class ArchiveWriter {

    # Creates a new ZIP archive at the given path. A file already there is left as it is,
    # unless `overwrite` is set.
    #
    # + path - Path of the ZIP file to create
    # + options - Options controlling how the archive is created
    # + return - `()` on success, or an error
    public isolated function init(string path, CompressOptions options = {}) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Adds a file from the local file system.
    #
    # + sourcePath - Path of the file to add
    # + entryName - Name to store the entry under, defaulting to the file name
    # + return - `()` on success, or an error
    public isolated function addFile(string sourcePath, string? entryName = ()) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Adds a directory and everything inside it from the local file system.
    #
    # + sourcePath - Path of the directory to add
    # + entryName - Name to store the directory under, defaulting to the directory name
    # + return - `()` on success, or an error
    public isolated function addDirectory(string sourcePath, string? entryName = ()) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Adds an entry with the given content, supplied as a byte array or as a stream.
    #
    # + entryName - Name to store the entry under
    # + content - Content of the entry
    # + return - `()` on success, or an error
    public isolated function addEntry(string entryName,
            byte[]|stream<byte[], error?> content) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Copies an entry from another archive without decompressing it.
    #
    # + sourceArchive - Archive to copy the entry from
    # + entryName - Name of the entry within the source archive
    # + return - `()` on success, or an error
    public isolated function copyEntry(ArchiveReader sourceArchive, string entryName) returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }

    # Completes the archive and closes the underlying file.
    #
    # + return - `()` on success, or an error
    public isolated function close() returns Error? {
        // TODO: implement
        return error Error("not implemented");
    }
}
