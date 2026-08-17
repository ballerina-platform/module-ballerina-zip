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

import io.ballerina.runtime.api.values.BHandle;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BTypedesc;

/**
 * Reads ZIP archives on behalf of the {@code zip} module. Every method is declared so that the
 * Ballerina side of the API compiles against the surface it expects; none of them carries an
 * implementation yet.
 */
public final class Reader {

    private Reader() {
    }

    public static Object nativeOpen(BString path) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeEntries(BHandle archive) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeOpenEntry(BHandle archive, BString name) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeReadChunk(BHandle entryStream, long size) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeCloseEntry(BHandle entryStream) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeExtractEntry(BHandle archive, BString name, BString targetPath) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object nativeCloseArchive(BHandle archive) {
        throw new UnsupportedOperationException("not implemented");
    }

    public static Object readEntry(BObject reader, BString name, BTypedesc targetType) {
        throw new UnsupportedOperationException("not implemented");
    }
}
