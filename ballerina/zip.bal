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

# Creates a ZIP archive from a file or a directory.
#
# ```ballerina
# check zip:compress("./reports", "./reports.zip");
# ```
#
# + sourcePath - Path of the file or directory to archive
# + targetPath - Path of the ZIP file to create
# + options - Options controlling how the archive is created
# + return - `()` on success, or an error
public isolated function compress(string sourcePath, string targetPath,
        CompressOptions options = {}) returns Error? {
    // TODO: implement
    return error Error("not implemented");
}

# Extracts every entry of a ZIP archive into a directory.
#
# ```ballerina
# check zip:decompress("./reports.zip", "./reports");
# ```
#
# + sourcePath - Path of the ZIP file to extract
# + targetPath - Path of the directory to extract into, created if it is missing
# + options - Options controlling how the archive is extracted
# + return - `()` on success, or an error
public isolated function decompress(string sourcePath, string targetPath,
        DecompressOptions options = {}) returns Error? {
    // TODO: implement
    return error Error("not implemented");
}

# Lists the entries of a ZIP archive without extracting it.
#
# + path - Path of the ZIP file to read
# + return - Metadata of every entry, in the order stored, or an error
public isolated function listEntries(string path) returns Entry[]|Error {
    // TODO: implement
    return error Error("not implemented");
}
