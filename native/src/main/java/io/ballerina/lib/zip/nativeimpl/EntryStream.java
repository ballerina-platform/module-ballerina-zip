/*
 * Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.zip.nativeimpl;

import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * A read position within one entry of an open archive. More than one may be open on the same archive
 * at a time. Closing the archive closes all of them.
 */
final class EntryStream {

    private final ZipArchive archive;
    private final InputStream content;
    private final AtomicBoolean closed = new AtomicBoolean();

    EntryStream(ZipArchive archive, InputStream content) {
        this.archive = archive;
        this.content = content;
    }

    boolean isClosed() {
        return closed.get();
    }

    /**
     * Reads up to {@code size} bytes. Returns {@code null} once the entry is exhausted, releasing the
     * read position at that point so that a stream read to the end needs no closing.
     */
    byte[] read(int size) throws IOException {
        byte[] buffer = new byte[size];
        int filled = 0;
        while (filled < size) {
            int count = content.read(buffer, filled, size - filled);
            if (count < 0) {
                break;
            }
            filled += count;
        }
        if (filled == 0) {
            close();
            return null;
        }
        if (filled == size) {
            return buffer;
        }
        byte[] chunk = new byte[filled];
        System.arraycopy(buffer, 0, chunk, 0, filled);
        return chunk;
    }

    void close() throws IOException {
        // The archive is told about the closing without holding a lock of this stream: closing the
        // archive walks its open streams, and taking the two locks in both orders can deadlock.
        if (closed.compareAndSet(false, true)) {
            archive.streamClosed(this);
            content.close();
        }
    }

    void closeByArchive() {
        if (closed.compareAndSet(false, true)) {
            try {
                content.close();
            } catch (IOException e) {
                // Nothing can be done about a failure to release a read position, and the caller
                // closing the archive is not interested in it.
            }
        }
    }
}
