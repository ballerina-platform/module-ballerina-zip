/*
 * Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com)
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

import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BHandle;
import io.ballerina.runtime.api.values.BString;

/**
 * Writes ZIP archives on behalf of the {@code zip} module. Every method is declared so that the
 * Ballerina side of the API compiles against the surface it expects; none of them carries an
 * implementation yet.
 */
public final class Writer {

    private Writer() {
    }

    public static Object nativeCreate(BString path, BString level) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeAddFile(BHandle writer, BString entryName, BString sourcePath) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeStartEntry(BHandle writer, BString entryName) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeWriteChunk(BHandle writer, BArray content) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeFinishEntry(BHandle writer) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeCopyEntry(BHandle writer, BHandle sourceArchive, BString entryName) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeCloseWriter(BHandle writer) {
        throw new UnsupportedOperationException("not implemented");
    }
}
