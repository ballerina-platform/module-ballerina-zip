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
import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.PosixFilePermission;
import java.util.Set;
import java.util.zip.Deflater;
import java.util.zip.ZipEntry;
import java.util.zip.ZipException;

/**
 * One ZIP file being written, and the compression the caller asked for. Names arrive already checked
 * and already in the form they are stored in; a name ending in {@code /} is a directory entry.
 */
final class ZipWriter {

    private static final PosixFilePermission[] PERMISSIONS = {
            PosixFilePermission.OWNER_READ,
            PosixFilePermission.OWNER_WRITE,
            PosixFilePermission.OWNER_EXECUTE,
            PosixFilePermission.GROUP_READ,
            PosixFilePermission.GROUP_WRITE,
            PosixFilePermission.GROUP_EXECUTE,
            PosixFilePermission.OTHERS_READ,
            PosixFilePermission.OTHERS_WRITE,
            PosixFilePermission.OTHERS_EXECUTE
    };

    private static final int DIRECTORY_KIND = 040000;
    private static final int FILE_KIND = 0100000;

    private final ZipArchiveOutputStream out;
    private final int method;
    private boolean closed;

    ZipWriter(ZipArchiveOutputStream out, String level) {
        this.out = out;
        this.method = "NONE".equals(level) ? ZipEntry.STORED : ZipEntry.DEFLATED;
        out.setMethod(method);
        out.setLevel(deflateLevel(level));
    }

    synchronized boolean isClosed() {
        return closed;
    }

    /**
     * Writes an entry holding the content of a file, or a directory entry when the name ends in
     * {@code /}. The time and, where the platform has them, the permissions come from the source.
     */
    synchronized void addFile(Path source, String entryName) throws IOException {
        BasicFileAttributes attributes = Files.readAttributes(source, BasicFileAttributes.class);
        ZipArchiveEntry entry = new ZipArchiveEntry(entryName);
        entry.setTime(attributes.lastModifiedTime());
        setUnixMode(entry, source);
        if (entry.isDirectory()) {
            entry.setMethod(ZipEntry.STORED);
            entry.setSize(0);
            out.putArchiveEntry(entry);
            out.closeArchiveEntry();
            return;
        }
        entry.setMethod(method);
        entry.setSize(attributes.size());
        out.putArchiveEntry(entry);
        // The entry is closed whatever the copy does. An entry left open is one the central directory
        // cannot be written after, so a file that could not be read would cost the whole archive
        // rather than the one entry.
        try {
            Files.copy(source, out);
        } finally {
            out.closeArchiveEntry();
        }
    }

    /**
     * Opens an entry whose content the caller writes in chunks. The time is the current one, since
     * there is no source file to take one from.
     */
    synchronized void startEntry(String entryName) throws IOException {
        ZipArchiveEntry entry = new ZipArchiveEntry(entryName);
        entry.setTime(System.currentTimeMillis());
        if (entry.isDirectory()) {
            entry.setMethod(ZipEntry.STORED);
            entry.setSize(0);
        } else {
            entry.setMethod(method);
        }
        out.putArchiveEntry(entry);
    }

    synchronized void writeChunk(byte[] chunk) throws IOException {
        out.write(chunk, 0, chunk.length);
    }

    synchronized void finishEntry() throws IOException {
        out.closeArchiveEntry();
    }

    /**
     * Writes the entry at the given position of another archive as it is stored there. The bytes are
     * copied still compressed, so an entry this library cannot decompress can be copied all the same.
     */
    synchronized void copyEntry(ZipArchive source, int index) throws IOException {
        ZipArchiveEntry entry = source.entryAt(index);
        InputStream raw = source.rawContentOf(entry);
        if (raw == null) {
            throw new IOException("the entry has no readable content");
        }
        try (InputStream content = raw) {
            // The name is the one this library decoded, not the one the implementation underneath
            // decoded, so that a copied entry keeps the name it was reached by.
            out.addRawArchiveEntry(new RenamedEntry(entry, source.nameAt(index)), content);
        }
    }

    synchronized void close() throws IOException {
        if (closed) {
            return;
        }
        closed = true;
        out.close();
    }

    private static int deflateLevel(String level) {
        return switch (level) {
            case "NONE" -> Deflater.NO_COMPRESSION;
            case "FASTEST" -> Deflater.BEST_SPEED;
            case "BEST" -> Deflater.BEST_COMPRESSION;
            default -> Deflater.DEFAULT_COMPRESSION;
        };
    }

    private static void setUnixMode(ZipArchiveEntry entry, Path source) {
        Set<PosixFilePermission> permissions;
        try {
            permissions = Files.getPosixFilePermissions(source);
        } catch (IOException | UnsupportedOperationException e) {
            // A platform that does not keep Unix permissions records none, and `Entry.unixMode` is
            // then absent when the archive is read back.
            return;
        }
        int mode = 0;
        for (int index = 0; index < PERMISSIONS.length; index++) {
            if (permissions.contains(PERMISSIONS[index])) {
                mode |= 1 << (PERMISSIONS.length - 1 - index);
            }
        }
        entry.setUnixMode((entry.isDirectory() ? DIRECTORY_KIND : FILE_KIND) | mode);
    }

    /**
     * A copy of an entry of another archive under the name this library reads it by. The name of an
     * entry can only be set from inside the class, which is what this subclass is for.
     */
    private static final class RenamedEntry extends ZipArchiveEntry {

        private RenamedEntry(ZipArchiveEntry source, String name) throws ZipException {
            super(source);
            setName(name);
        }
    }
}
