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

import org.apache.commons.compress.archivers.zip.ZipArchiveEntry;
import org.apache.commons.compress.archivers.zip.ZipFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * One open ZIP file, its index of entries in stored order, and the entry streams handed out from it.
 * The index is read once when the archive is opened, so the archive is seen as it was at that moment.
 *
 * <p>Nothing here is synchronized. {@code ArchiveReader} is not an isolated class, so isolated code
 * cannot share one reader and no two strands reach this object through it. One reader belongs to one
 * strand, as one writer does.
 */
final class ZipArchive {

    private final ZipFile zipFile;
    private final List<ZipArchiveEntry> entriesInStoredOrder = new ArrayList<>();
    private final Map<String, Integer> firstIndexByName = new HashMap<>();
    private final List<String> names = new ArrayList<>();
    private final Set<EntryStream> openStreams = new LinkedHashSet<>();
    private boolean closed;

    ZipArchive(ZipFile zipFile) {
        this.zipFile = zipFile;
        // Every entry counted here has a central directory record physically present in the file, so
        // nothing is allocated from the entry count declared in the trailer, which can be untrue.
        Enumeration<ZipArchiveEntry> stored = zipFile.getEntriesInPhysicalOrder();
        while (stored.hasMoreElements()) {
            ZipArchiveEntry entry = stored.nextElement();
            String name = EntryNames.of(entry);
            firstIndexByName.putIfAbsent(name, entriesInStoredOrder.size());
            entriesInStoredOrder.add(entry);
            names.add(name);
        }
    }

    boolean isClosed() {
        return closed;
    }

    int size() {
        return entriesInStoredOrder.size();
    }

    ZipArchiveEntry entryAt(int index) {
        return entriesInStoredOrder.get(index);
    }

    String nameAt(int index) {
        return names.get(index);
    }

    /**
     * Returns the position of the first entry with the given name, or {@code -1} if there is none.
     * A ZIP file may hold more than one entry with the same name; the first one is the one reachable
     * by name.
     */
    int firstIndexOf(String name) {
        Integer index = firstIndexByName.get(name);
        return index == null ? -1 : index;
    }

    boolean canReadEntryData(ZipArchiveEntry entry) {
        return zipFile.canReadEntryData(entry);
    }

    InputStream contentOf(ZipArchiveEntry entry) throws IOException {
        return zipFile.getInputStream(entry);
    }

    /**
     * Returns the content of an entry as it is stored, still compressed and never decoded, which is
     * what lets an entry be copied into another archive whatever it holds. {@code null} where the
     * archive does not say at which offset the content of the entry begins.
     */
    InputStream rawContentOf(ZipArchiveEntry entry) throws IOException {
        return zipFile.getRawInputStream(entry);
    }

    EntryStream openStream(ZipArchiveEntry entry) throws IOException {
        EntryStream stream = new EntryStream(this, zipFile.getInputStream(entry));
        openStreams.add(stream);
        return stream;
    }

    /**
     * Returns a stream over an entry that holds no content, such as a directory. Handed out by the
     * archive like any other, so that it is closed when the archive is and answers a read afterwards
     * the same way the stream of a file would.
     */
    EntryStream openEmptyStream() {
        EntryStream stream = new EntryStream(this, new ByteArrayInputStream(new byte[0]));
        openStreams.add(stream);
        return stream;
    }

    void streamClosed(EntryStream stream) {
        openStreams.remove(stream);
    }

    void close() throws IOException {
        if (closed) {
            return;
        }
        closed = true;
        for (EntryStream stream : new ArrayList<>(openStreams)) {
            stream.closeByArchive();
        }
        openStreams.clear();
        zipFile.close();
    }
}
