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

import java.nio.charset.StandardCharsets;

/**
 * Decodes the raw bytes of an entry name into text. The general purpose bit flag of the entry
 * decides the character set: UTF-8 when it is set, CP437 when it is clear.
 * <p>
 * The bytes are taken from {@code getRawName} and decoded here so that an archive is read the same
 * way once Apache Commons Compress gives way to Go's {@code archive/zip}, which hands over a name
 * exactly as stored and rewrites nothing. Commons does rewrite: {@code ZipArchiveEntry.setName}
 * turns {@code \} into {@code /} for an entry recorded as made on a FAT platform, which is what a
 * Windows tool writes. Through {@code getName}, {@code a\b.txt} would arrive as a valid two part
 * path today and as the {@code UnsafePathError} that sections 7.4 and 8.1 require after the swap,
 * and nothing would say that the same archive had started extracting differently. Reading the
 * stored bytes also keeps the flag the only thing that decides the character set, since an InfoZIP
 * Unicode path field replaces the decoded name and leaves the raw bytes alone.
 */
final class EntryNames {

    // Unicode values of the bytes 0x80 to 0xFF in CP437. The bytes 0x00 to 0x7F map to the same
    // code point, so CP437 maps all 256 byte values and decoding never fails. The table is written
    // out here rather than taken from `Charset.forName("IBM437")`, which the JVM does have, to hold
    // the mapping still: what a native image carries of the character sets of the JVM is not
    // something this repository has established, and the package declares `graalvmCompatible`. The
    // table is checked against the character set of the JVM, value by value, in `cp437_test.bal`.
    private static final String CP437_HIGH_HALF =
            "\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF"
            + "\u00EE\u00EC\u00C4\u00C5\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9"
            + "\u00FF\u00D6\u00DC\u00A2\u00A3\u00A5\u20A7\u0192\u00E1\u00ED\u00F3\u00FA"
            + "\u00F1\u00D1\u00AA\u00BA\u00BF\u2310\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB"
            + "\u2591\u2592\u2593\u2502\u2524\u2561\u2562\u2556\u2555\u2563\u2551\u2557"
            + "\u255D\u255C\u255B\u2510\u2514\u2534\u252C\u251C\u2500\u253C\u255E\u255F"
            + "\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u2567\u2568\u2564\u2565\u2559"
            + "\u2558\u2552\u2553\u256B\u256A\u2518\u250C\u2588\u2584\u258C\u2590\u2580"
            + "\u03B1\u00DF\u0393\u03C0\u03A3\u03C3\u00B5\u03C4\u03A6\u0398\u03A9\u03B4"
            + "\u221E\u03C6\u03B5\u2229\u2261\u00B1\u2265\u2264\u2320\u2321\u00F7\u2248"
            + "\u00B0\u2219\u00B7\u221A\u207F\u00B2\u25A0\u00A0";

    private EntryNames() {
    }

    static String of(ZipArchiveEntry entry) {
        byte[] raw = entry.getRawName();
        if (raw == null) {
            return entry.getName();
        }
        if (entry.getGeneralPurposeBit().usesUTF8ForNames()) {
            return new String(raw, StandardCharsets.UTF_8);
        }
        return decodeCp437(raw);
    }

    private static String decodeCp437(byte[] raw) {
        StringBuilder decoded = new StringBuilder(raw.length);
        for (byte b : raw) {
            int value = b & 0xFF;
            decoded.append(value < 0x80 ? (char) value : CP437_HIGH_HALF.charAt(value - 0x80));
        }
        return decoded.toString();
    }
}
