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
import ballerina/zip;

public function main() returns error? {
    // Refusing an entry that would be written outside the target directory always applies. None of
    // these limits do unless they are set: every field is optional, and an absent one means no limit.
    zip:DecompressOptions guarded = {
        fileWriteMode: zip:REPLACE,
        limits: {
            maxEntries: 500,
            maxTotalSize: 100 * 1024 * 1024,
            maxCompressionRatio: 50
        }
    };

    foreach string name in ["reports", "bomb"] {
        string target = string `./unpacked/${name}`;
        zip:Error? outcome = zip:decompress(string `./resources/${name}.zip`, target, guarded);

        // Each guard has its own error type, so a hostile archive can be told from a broken one.
        if outcome is zip:LimitExceededError {
            check discardPartialOutput(target);
            io:println(name, " refused: ", outcome.message());
        } else if outcome is zip:UnsafePathError {
            check discardPartialOutput(target);
            io:println(name, " refused: ", outcome.message());
        } else {
            check outcome;
            io:println(name, " unpacked into ", target);
        }
    }
}

isolated function discardPartialOutput(string target) returns error? {
    // The limits are measured as the archive is read, so a refused extraction leaves what it had
    // already written on disk, where it could be mistaken for a complete one.
    if check file:test(target, file:EXISTS) {
        check file:remove(target, file:RECURSIVE);
    }
}
