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
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;

import java.util.Map;

/**
 * Creates the error values defined by the {@code zip} module. Messages are always written here, so
 * that no message of the underlying ZIP implementation ever reaches the caller.
 */
final class ZipErrors {

    private static final String ENTRY_ERROR_DETAIL = "EntryErrorDetail";
    private static final String ENTRY_NAME = "entryName";

    private static final String INVALID_ARCHIVE_ERROR = "InvalidArchiveError";
    private static final String ENTRY_NOT_FOUND_ERROR = "EntryNotFoundError";
    private static final String UNSUPPORTED_ENTRY_ERROR = "UnsupportedEntryError";
    private static final String FILE_SYSTEM_ERROR = "FileSystemError";

    private ZipErrors() {
    }

    static BError invalidArchive(String message) {
        return error(INVALID_ARCHIVE_ERROR, message, null);
    }

    static BError entryNotFound(String message) {
        return error(ENTRY_NOT_FOUND_ERROR, message, null);
    }

    static BError unsupportedEntry(String message, String entryName) {
        return error(UNSUPPORTED_ENTRY_ERROR, message, entryName);
    }

    static BError fileSystem(String message) {
        return error(FILE_SYSTEM_ERROR, message, null);
    }

    private static BError error(String typeName, String message, String entryName) {
        BString messageValue = StringUtils.fromString(message);
        if (entryName == null) {
            return ErrorCreator.createError(ModuleUtils.getModule(), typeName, messageValue, null, null);
        }
        BMap<BString, Object> detail = ValueCreator.createRecordValue(ModuleUtils.getModule(), ENTRY_ERROR_DETAIL,
                Map.of(ENTRY_NAME, StringUtils.fromString(entryName)));
        return ErrorCreator.createError(ModuleUtils.getModule(), typeName, messageValue, null, detail);
    }
}
