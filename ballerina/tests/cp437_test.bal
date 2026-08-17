// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/jballerina.java;
import ballerina/jballerina.java.arrays as jarrays;
import ballerina/test;

// The module carries its own CP437 table rather than asking the JVM for the character set, so that
// what a name decodes to is fixed. The table has to say what the character set of the JVM says, and
// this is where that is checked: every byte value the format allows in a name is the name of an
// entry of `cp437-table.zip`, so listing it decodes the whole table through the module itself.
@test:Config {}
isolated function testTheCp437TableAgreesWithTheCharacterSetOfTheJvm() returns error? {
    if isNativeImage() {
        // A native image carries only the character sets it is built with, and CP437 is not one of
        // them, so there is nothing to check the table against here. What the table has to say is
        // fixed when it is written, so checking it on the JVM checks it everywhere.
        return;
    }

    ArchiveReader reader = check new (CP437_TABLE_ARCHIVE);
    Entry[] entries = check reader.entries();
    check reader.close();

    byte[] lowHalf = [];
    foreach int value in 0x01 ... 0x7F {
        lowHalf.push(<byte>value);
    }
    byte[] highHalf = [];
    foreach int value in 0x80 ... 0xFF {
        highHalf.push(<byte>value);
    }
    test:assertEquals(entries[0].name, check decodeWithJvmCharset(lowHalf, "IBM437"));
    test:assertEquals(entries[1].name, check decodeWithJvmCharset(highHalf, "IBM437"));
}

isolated function isNativeImage() returns boolean {
    // A native image sets this property at run time; a JVM never has it.
    handle imageCode = getSystemProperty(java:fromString("org.graalvm.nativeimage.imagecode"));
    return java:toString(imageCode) !is ();
}

isolated function getSystemProperty(handle name) returns handle = @java:Method {
    'class: "java.lang.System",
    name: "getProperty",
    paramTypes: ["java.lang.String"]
} external;

isolated function decodeWithJvmCharset(byte[] content, string charsetName) returns string|error {
    handle decoded = check newJavaString(check jarrays:toHandle(content, "byte"), java:fromString(charsetName));
    return java:toString(decoded) ?: "";
}

isolated function newJavaString(handle content, handle charsetName) returns handle|error = @java:Constructor {
    'class: "java.lang.String",
    paramTypes: ["[B", "java.lang.String"]
} external;
