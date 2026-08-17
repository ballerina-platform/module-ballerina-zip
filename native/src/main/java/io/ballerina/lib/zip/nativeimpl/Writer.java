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

import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BHandle;
import io.ballerina.runtime.api.values.BString;
import org.apache.commons.compress.archivers.zip.UnsupportedZipFeatureException;
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry;
import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream;

import java.io.IOException;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

/**
 * Writes ZIP archives on behalf of the {@code zip} module. This class moves bytes; which names are
 * allowed, which files are walked and which of them are skipped is decided by the Ballerina code
 * that calls it, and every name arrives here already checked.
 */
public final class Writer {

    private Writer() {
    }

    public static Object nativeCreate(BString path, BString level, boolean overwrite) {
        String target = path.getValue();
        Path file = FileSystem.pathOf(target);
        if (file == null) {
            return FileSystem.unrepresentablePath(target);
        }
        if (Files.isDirectory(file)) {
            return ZipErrors.fileSystem("'" + target + "' is a directory, not a path a ZIP file can be written to");
        }
        // Section 5.1: whether the path is free is left to `CREATE_NEW`, which fails if anything is
        // there, rather than asked beforehand, so that nothing can appear between the two. Under
        // `overwrite` whatever is there is truncated here, when the writer is created, rather than
        // when it is closed. `READ` is asked for as well because the sizes of an entry are written
        // back into its header once its content has been written.
        StandardOpenOption[] options = overwrite
                ? new StandardOpenOption[]{StandardOpenOption.CREATE, StandardOpenOption.WRITE,
                        StandardOpenOption.READ, StandardOpenOption.TRUNCATE_EXISTING}
                : new StandardOpenOption[]{StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE,
                        StandardOpenOption.READ};
        try {
            ZipArchiveOutputStream out = new ZipArchiveOutputStream(file, options);
            return ValueCreator.createHandleValue(new ZipWriter(out, level.getValue()));
        } catch (FileAlreadyExistsException e) {
            return ZipErrors.fileSystem("a file is already at '" + target
                    + "'; set 'overwrite' to replace it");
        } catch (IOException | UnsupportedOperationException e) {
            return ZipErrors.fileSystem("the file at '" + target + "' could not be created");
        }
    }

    public static Object nativeAddFile(BHandle writer, BString entryName, BString sourcePath) {
        ZipWriter zipWriter = (ZipWriter) writer.getValue();
        if (zipWriter.isClosed()) {
            return closedArchive();
        }
        String source = sourcePath.getValue();
        Path file = FileSystem.pathOf(source);
        if (file == null) {
            return FileSystem.unrepresentablePath(source);
        }
        if (!Files.exists(file)) {
            return ZipErrors.fileSystem("no file exists at '" + source + "'");
        }
        try {
            zipWriter.addFile(file, entryName.getValue());
            return null;
        } catch (IOException e) {
            return ZipErrors.fileSystem("the file at '" + source + "' could not be added to the archive");
        }
    }

    public static Object nativeStartEntry(BHandle writer, BString entryName) {
        ZipWriter zipWriter = (ZipWriter) writer.getValue();
        if (zipWriter.isClosed()) {
            return closedArchive();
        }
        try {
            zipWriter.startEntry(entryName.getValue());
            return null;
        } catch (IOException e) {
            return ZipErrors.fileSystem("entry '" + entryName.getValue() + "' could not be added to the archive");
        }
    }

    public static Object nativeWriteChunk(BHandle writer, BArray content) {
        ZipWriter zipWriter = (ZipWriter) writer.getValue();
        if (zipWriter.isClosed()) {
            return closedArchive();
        }
        try {
            zipWriter.writeChunk(content.getBytes());
            return null;
        } catch (IOException e) {
            return ZipErrors.fileSystem("the content of the entry could not be written to the archive");
        }
    }

    public static Object nativeFinishEntry(BHandle writer) {
        ZipWriter zipWriter = (ZipWriter) writer.getValue();
        if (zipWriter.isClosed()) {
            return closedArchive();
        }
        try {
            zipWriter.finishEntry();
            return null;
        } catch (IOException e) {
            return ZipErrors.fileSystem("the entry could not be completed");
        }
    }

    public static Object nativeCopyEntry(BHandle writer, BHandle sourceArchive, BString entryName) {
        ZipWriter zipWriter = (ZipWriter) writer.getValue();
        if (zipWriter.isClosed()) {
            return closedArchive();
        }
        ZipArchive source = (ZipArchive) sourceArchive.getValue();
        if (source.isClosed()) {
            return ZipErrors.invalidArchive("the archive the entry is copied from is closed");
        }
        String name = entryName.getValue();
        int index = source.firstIndexOf(name);
        if (index < 0) {
            return ZipErrors.entryNotFound("the archive holds no entry named '" + name + "'");
        }
        ZipArchiveEntry entry = source.entryAt(index);
        if (entry.getGeneralPurposeBit().usesEncryption()) {
            // The bytes could be carried across untouched, but the flag saying they are encrypted
            // cannot: what would be written is a header saying the content is plain over content
            // that is not. A password-protected entry is unsupported, as section 11 says.
            return ZipErrors.unsupportedEntry("entry '" + name + "' is encrypted, and an encrypted entry cannot "
                    + "be written into another archive", name);
        }
        try {
            zipWriter.copyEntry(source, index);
            return null;
        } catch (UnsupportedZipFeatureException e) {
            return ZipErrors.unsupportedEntry("entry '" + name + "' is stored in a way that cannot be written "
                    + "into another archive", name);
        } catch (IOException e) {
            return ZipErrors.invalidArchive("entry '" + name + "' could not be copied from the archive");
        }
    }

    public static Object nativeCloseWriter(BHandle writer) {
        ZipWriter zipWriter = (ZipWriter) writer.getValue();
        try {
            zipWriter.close();
            return null;
        } catch (IOException e) {
            // The central directory is written by `close`, so a failure here is what stands between
            // the file and being a valid archive.
            return ZipErrors.fileSystem("the archive could not be completed");
        }
    }

    private static Object closedArchive() {
        return ZipErrors.invalidArchive("the archive is closed");
    }
}
