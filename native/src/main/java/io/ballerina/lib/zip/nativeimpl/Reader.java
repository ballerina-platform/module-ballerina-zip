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

import io.ballerina.lib.zip.ModuleUtils;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.PredefinedTypes;
import io.ballerina.runtime.api.types.StreamType;
import io.ballerina.runtime.api.types.TupleType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BHandle;
import io.ballerina.runtime.api.values.BListInitialValueEntry;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BTypedesc;
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry;
import org.apache.commons.compress.archivers.zip.ZipFile;
import org.apache.commons.compress.utils.InputStreamStatistics;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * Reads ZIP archives on behalf of the {@code zip} module. This class moves bytes and reports what the
 * archive holds; every decision taken on top of that - path safety, extraction limits, write modes -
 * is made by the Ballerina code that calls it.
 */
public final class Reader {

    private static final String ENTRY_RECORD = "Entry";
    private static final String ARCHIVE_FIELD = "archive";
    private static final int COPY_BUFFER_SIZE = 8192;
    // The mode as the archive records it, setuid, setgid and sticky included. Only the bits saying
    // what kind of file it is are left out, since `isSymlink` and `isDirectory` report that.
    private static final int UNIX_MODE_BITS = 07777;
    private static final int STORED_METHOD = 0;
    private static final int DEFLATED_METHOD = 8;
    // What `nativeExtractEntry` returns in place of a byte count when a limit stops the write. Which
    // limit it was is told apart here, since the caller cannot work it out from the sizes the archive
    // claims and has to know which `LimitExceededError` to give.
    private static final long SIZE_EXCEEDED = -1L;
    private static final long RATIO_EXCEEDED = -2L;
    private static final TupleType UTC_TYPE = TypeCreator.createTupleType(
            List.of(PredefinedTypes.TYPE_INT, PredefinedTypes.TYPE_DECIMAL), PredefinedTypes.TYPE_NEVER, 0, true);

    private Reader() {
    }

    public static Object nativeOpen(BString path) {
        String archivePath = path.getValue();
        File file = new File(archivePath);
        if (!file.exists()) {
            return ZipErrors.fileSystem("no file exists at '" + archivePath + "'");
        }
        if (file.isDirectory()) {
            return ZipErrors.fileSystem("'" + archivePath + "' is a directory, not a ZIP file");
        }
        if (!file.canRead()) {
            return ZipErrors.fileSystem("the file at '" + archivePath + "' cannot be read");
        }
        try {
            // The general purpose bit flag of each entry is the only thing that decides how its name
            // is decoded, as section 7.4 says. The Unicode extra fields are switched off because an
            // InfoZIP Unicode path field would otherwise be a third source of a name, which that
            // section does not allow for. The raw name bytes are decoded in `EntryNames`.
            ZipFile zipFile = ZipFile.builder().setFile(file).setUseUnicodeExtraFields(false).get();
            return ValueCreator.createHandleValue(new ZipArchive(zipFile));
        } catch (IOException e) {
            // The file is there and can be read, so what is wrong is what is in it.
            return ZipErrors.invalidArchive("the file at '" + archivePath + "' is not a valid ZIP archive");
        }
    }

    public static Object nativeEntries(BHandle archive) {
        ZipArchive zipArchive = (ZipArchive) archive.getValue();
        if (zipArchive.isClosed()) {
            return closedArchive();
        }
        BMap<BString, Object>[] entries = new BMap[zipArchive.size()];
        for (int index = 0; index < entries.length; index++) {
            entries[index] = toEntryRecord(zipArchive.entryAt(index), zipArchive.nameAt(index));
        }
        return ValueCreator.createArrayValue(entries, TypeCreator.createArrayType(entryType()));
    }

    public static Object nativeOpenEntry(BHandle archive, BString name) {
        ZipArchive zipArchive = (ZipArchive) archive.getValue();
        if (zipArchive.isClosed()) {
            return closedArchive();
        }
        String entryName = name.getValue();
        int index = zipArchive.firstIndexOf(entryName);
        if (index < 0) {
            return ZipErrors.entryNotFound("the archive holds no entry named '" + entryName + "'");
        }
        ZipArchiveEntry entry = zipArchive.entryAt(index);
        if (entry.isDirectory()) {
            return ValueCreator.createHandleValue(zipArchive.openEmptyStream());
        }
        Object unreadable = readableOrError(zipArchive, entry, entryName);
        if (unreadable != null) {
            return unreadable;
        }
        try {
            return ValueCreator.createHandleValue(zipArchive.openStream(entry));
        } catch (IOException e) {
            return ZipErrors.invalidArchive("the content of entry '" + entryName + "' could not be read");
        }
    }

    public static Object nativeReadChunk(BHandle entryStream, long size) {
        EntryStream stream = (EntryStream) entryStream.getValue();
        if (stream.isClosed()) {
            return ZipErrors.invalidArchive("the entry stream is closed");
        }
        try {
            byte[] chunk = stream.read((int) size);
            return chunk == null ? null : ValueCreator.createArrayValue(chunk);
        } catch (IOException e) {
            return ZipErrors.invalidArchive("the content of the entry could not be read");
        }
    }

    public static Object nativeCloseEntry(BHandle entryStream) {
        EntryStream stream = (EntryStream) entryStream.getValue();
        try {
            stream.close();
            return null;
        } catch (IOException e) {
            return ZipErrors.invalidArchive("the entry stream could not be closed");
        }
    }

    /**
     * Writes the content of the entry at the given position to the given path, and returns the number
     * of bytes written. Writing stops before the byte after {@code byteLimit} and {@code -1} is
     * returned; a negative {@code byteLimit} means no ceiling. Writing also stops, with {@code -2},
     * once the entry has produced more than {@code maxCompressionRatio} bytes for every compressed
     * byte taken from the archive; a ratio of zero or less means no ceiling. The caller decides what
     * either ceiling is and what a breach of it means.
     */
    public static Object nativeExtractEntry(BHandle archive, long entryIndex, BString targetPath, long byteLimit,
                                            long maxCompressionRatio) {
        ZipArchive zipArchive = (ZipArchive) archive.getValue();
        if (zipArchive.isClosed()) {
            return closedArchive();
        }
        if (entryIndex < 0 || entryIndex >= zipArchive.size()) {
            return ZipErrors.invalidArchive("the archive holds no entry at position " + entryIndex);
        }
        int index = (int) entryIndex;
        ZipArchiveEntry entry = zipArchive.entryAt(index);
        String entryName = zipArchive.nameAt(index);
        Object unreadable = readableOrError(zipArchive, entry, entryName);
        if (unreadable != null) {
            return unreadable;
        }
        Path target = Paths.get(targetPath.getValue());
        try (InputStream content = zipArchive.contentOf(entry)) {
            return copy(content, target, entryName, byteLimit, maxCompressionRatio);
        } catch (IOException e) {
            return ZipErrors.invalidArchive("the content of entry '" + entryName + "' could not be read");
        }
    }

    public static Object nativeCloseArchive(BHandle archive) {
        ZipArchive zipArchive = (ZipArchive) archive.getValue();
        try {
            zipArchive.close();
            return null;
        } catch (IOException e) {
            return ZipErrors.fileSystem("the archive could not be closed");
        }
    }

    /**
     * Reads the content of an entry either into an array or into a stream of chunks. The dispatch is
     * made here because a dependently typed function has to be external.
     */
    public static Object readEntry(BObject reader, BString name, BTypedesc targetType) {
        Object archive = reader.get(StringUtils.fromString(ARCHIVE_FIELD));
        if (!(archive instanceof BHandle handle)) {
            return closedArchive();
        }
        Object opened = nativeOpenEntry(handle, name);
        if (!(opened instanceof BHandle openedStream)) {
            return opened;
        }
        Type described = TypeUtils.getImpliedType(targetType.getDescribingType());
        if (described.getTag() == TypeTags.STREAM_TAG) {
            BObject iterator = ValueCreator.createObjectValue(ModuleUtils.getModule(), "EntryByteStream",
                    openedStream);
            return ValueCreator.createStreamValue((StreamType) described, iterator);
        }
        return readFully((EntryStream) openedStream.getValue(), name.getValue());
    }

    private static Object readFully(EntryStream stream, String entryName) {
        ByteArrayOutputStream content = new ByteArrayOutputStream();
        try {
            while (true) {
                byte[] chunk = stream.read(COPY_BUFFER_SIZE);
                if (chunk == null) {
                    break;
                }
                content.write(chunk);
            }
        } catch (IOException e) {
            // The read position is released here, since the caller is given no stream to close.
            nativeCloseEntry(ValueCreator.createHandleValue(stream));
            return ZipErrors.invalidArchive("the content of entry '" + entryName + "' could not be read");
        }
        return ValueCreator.createArrayValue(content.toByteArray());
    }

    private static Object copy(InputStream content, Path target, String entryName, long byteLimit,
                               long maxCompressionRatio) {
        long written = 0;
        byte[] buffer = new byte[COPY_BUFFER_SIZE];
        try (OutputStream out = Files.newOutputStream(target, StandardOpenOption.CREATE,
                StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING)) {
            while (true) {
                int count;
                try {
                    count = content.read(buffer);
                } catch (IOException e) {
                    return ZipErrors.invalidArchive("the content of entry '" + entryName + "' could not be read");
                }
                if (count < 0) {
                    return written;
                }
                // Both ceilings are tested before the chunk is written, so neither is passed by the
                // size of one buffer.
                if (byteLimit >= 0 && written + count > byteLimit) {
                    return SIZE_EXCEEDED;
                }
                if (ratioExceeded(content, written + count, maxCompressionRatio)) {
                    return RATIO_EXCEEDED;
                }
                out.write(buffer, 0, count);
                written += count;
            }
        } catch (IOException e) {
            return ZipErrors.fileSystem("entry '" + entryName + "' could not be written to '" + target + "'");
        }
    }

    /**
     * Whether an entry has expanded past the ratio allowed, measured against the compressed bytes
     * taken from the archive so far rather than the compressed size the archive claims for it, which
     * can be untrue. An entry from which no compressed byte has yet been taken has no ratio, and
     * neither has one whose stream cannot say how much it has consumed.
     */
    private static boolean ratioExceeded(InputStream content, long written, long maxCompressionRatio) {
        if (maxCompressionRatio <= 0 || !(content instanceof InputStreamStatistics statistics)) {
            return false;
        }
        long consumed = statistics.getCompressedCount();
        if (consumed <= 0 || maxCompressionRatio > Long.MAX_VALUE / consumed) {
            return false;
        }
        return written > maxCompressionRatio * consumed;
    }

    private static Object readableOrError(ZipArchive archive, ZipArchiveEntry entry, String entryName) {
        if (entry.getGeneralPurposeBit().usesEncryption()) {
            return ZipErrors.unsupportedEntry("entry '" + entryName + "' is encrypted", entryName);
        }
        // Only the two methods of the module are read, whatever else the implementation underneath is
        // able to decompress.
        if (entry.getMethod() != STORED_METHOD && entry.getMethod() != DEFLATED_METHOD) {
            return ZipErrors.unsupportedEntry(
                    "entry '" + entryName + "' uses a compression method that is not supported", entryName);
        }
        if (!archive.canReadEntryData(entry)) {
            return ZipErrors.unsupportedEntry(
                    "entry '" + entryName + "' uses a compression method that is not supported", entryName);
        }
        return null;
    }

    private static String methodNameOf(int method) {
        if (method == STORED_METHOD) {
            return "STORE";
        }
        if (method == DEFLATED_METHOD) {
            return "DEFLATE";
        }
        // Section 2.3: an entry stored by a method the module cannot decompress is listed all the
        // same, so `method` needs a value for it. Naming which method it is would put a format
        // detail in the API that no caller acts on, and reading it still gives an
        // `UnsupportedEntryError`.
        return "OTHER";
    }

    private static BMap<BString, Object> toEntryRecord(ZipArchiveEntry entry, String name) {
        Map<String, Object> fields = new HashMap<>();
        fields.put("name", StringUtils.fromString(name));
        fields.put("isDirectory", entry.isDirectory());
        fields.put("isSymlink", entry.isUnixSymlink());
        fields.put("uncompressedSize", Math.max(entry.getSize(), 0));
        fields.put("compressedSize", Math.max(entry.getCompressedSize(), 0));
        fields.put("method", StringUtils.fromString(methodNameOf(entry.getMethod())));
        fields.put("modifiedTime", utcOf(entry));
        fields.put("crc32", Math.max(entry.getCrc(), 0));
        String comment = entry.getComment();
        if (comment != null && !comment.isEmpty()) {
            fields.put("comment", StringUtils.fromString(comment));
        }
        int mode = entry.getUnixMode();
        if (mode != 0) {
            fields.put("unixMode", (long) (mode & UNIX_MODE_BITS));
        }
        return ValueCreator.createRecordValue(ModuleUtils.getModule(), ENTRY_RECORD, fields);
    }

    private static BArray utcOf(ZipArchiveEntry entry) {
        long millis = entry.getTime();
        if (millis < 0) {
            millis = 0;
        }
        long seconds = Math.floorDiv(millis, 1000L);
        long nanos = Math.floorMod(millis, 1000L) * 1_000_000L;
        if (entry.getLastModifiedTime() != null) {
            // An archive recording a more precise time than the two seconds of the format reports it.
            long preciseNanos = entry.getLastModifiedTime().to(TimeUnit.NANOSECONDS);
            seconds = Math.floorDiv(preciseNanos, 1_000_000_000L);
            nanos = Math.floorMod(preciseNanos, 1_000_000_000L);
        }
        // `time:Utc` is a readonly tuple, so both members are given at creation; a readonly value
        // cannot be filled in afterwards.
        return ValueCreator.createTupleValue(UTC_TYPE, 2, new BListInitialValueEntry[]{
                ValueCreator.createListInitialValueEntry(seconds),
                ValueCreator.createListInitialValueEntry(ValueCreator.createDecimalValue(
                        BigDecimal.valueOf(nanos, 9)))});
    }

    private static Type entryType() {
        return TypeUtils.getType(ValueCreator.createRecordValue(ModuleUtils.getModule(), ENTRY_RECORD));
    }

    private static Object closedArchive() {
        return ZipErrors.invalidArchive("the archive is closed");
    }
}
