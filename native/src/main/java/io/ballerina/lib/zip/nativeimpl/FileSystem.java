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

import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BString;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.attribute.FileTime;
import java.time.Instant;

/**
 * The things the Ballerina code cannot ask the platform for itself: the path of a file with every
 * link along it followed, whether two paths are one file, and the modified time of a file. Nothing
 * here knows about ZIP files.
 */
public final class FileSystem {

    private FileSystem() {
    }

    /**
     * Returns the path with every link along it followed. The {@code file} module cannot do this: its
     * {@code SYMLINK} normalization reads the target of a link and fails on a path that is not one.
     */
    public static Object nativeRealPath(BString path) {
        try {
            return StringUtils.fromString(Paths.get(path.getValue()).toRealPath().toString());
        } catch (IOException | SecurityException e) {
            return ZipErrors.fileSystem("the path '" + path.getValue() + "' could not be resolved");
        }
    }

    /**
     * Returns whether two paths are the same file. A resolved path settles this for a link that
     * carries a name of its own, but two hard links to one file are two names with nothing to
     * resolve between them, so the file system is asked directly.
     */
    public static Object nativeIsSameFile(BString first, BString second) {
        try {
            return Files.isSameFile(Paths.get(first.getValue()), Paths.get(second.getValue()));
        } catch (IOException | SecurityException e) {
            return ZipErrors.fileSystem(
                    "'" + first.getValue() + "' and '" + second.getValue() + "' could not be compared");
        }
    }

    /**
     * Sets the modified time of a file. A platform that cannot store one is left alone rather than
     * reported, since the content of the file is already written by then.
     */
    public static void nativeSetModifiedTime(BString path, long seconds, long nanos) {
        try {
            Files.setLastModifiedTime(Paths.get(path.getValue()),
                    FileTime.from(Instant.ofEpochSecond(seconds, nanos)));
        } catch (IOException | UnsupportedOperationException | IllegalArgumentException e) {
            // A platform that cannot store a modified time leaves the file with the one it has.
        }
    }
}
