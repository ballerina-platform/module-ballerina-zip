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

// How much of an entry is asked of the native layer at a time.
const CHUNK_SIZE = 65536;

// The read position behind a `stream<byte[], Error?>` handed out by `ArchiveReader.readEntry`. It is
// created by the native code, which is where the choice between an array and a stream is made, and it
// keeps the position open until the entry is read to the end or the stream is closed.
isolated class EntryByteStream {

    private final handle entryStream;

    isolated function init(handle entryStream) {
        self.entryStream = entryStream;
    }

    public isolated function next() returns record {|byte[] value;|}|Error? {
        byte[]? chunk = check nativeReadChunk(self.entryStream, CHUNK_SIZE);
        if chunk is () {
            return ();
        }
        return {value: chunk};
    }

    public isolated function close() returns Error? {
        return nativeCloseEntry(self.entryStream);
    }
}
