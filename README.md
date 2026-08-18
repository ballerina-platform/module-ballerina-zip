# Ballerina Zip Library

[![Build](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerina-zip/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerina-zip)
[![Trivy](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/trivy-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/trivy-scan.yml)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/build-with-bal-test-native.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/build-with-bal-test-native.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerina-zip.svg)](https://github.com/ballerina-platform/module-ballerina-zip/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/zip.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Fzip)

## Overview

The `zip` library provides APIs to create and read ZIP archives from Ballerina.

A file or a directory is archived with `compress` and unpacked with `decompress`, and what an archive holds can be listed with `listEntries` without unpacking it. For finer control, `ArchiveWriter` builds an archive entry by entry and `ArchiveReader` reads one entry at a time; both take and return content as byte streams, so an archive never has to be held in memory. An entry can also be moved between archives with `copyEntry`, which carries the stored bytes across without decompressing them.

An archive that arrives from outside a system is read defensively. An entry whose name would write outside the target directory, a symbolic link, and an entry that is encrypted or stored with a compression method the library does not support are each refused with their own error type. `ExtractionLimits` caps the number of entries, the total uncompressed size, and how far a single entry may expand beyond the size it stores, so an archive built to exhaust the disk is stopped rather than unpacked.

## Quickstart

To use the `zip` library in your Ballerina application, update the `.bal` file as follows.

### Step 1: Import the module

```ballerina
import ballerina/io;
import ballerina/zip;
```

### Step 2: Archive and unpack

The `limits` cap what an archive is allowed to expand to, so one built to exhaust the disk is stopped rather than unpacked.

```ballerina
public function main() returns error? {
    check zip:compress("./reports", "./reports.zip");

    zip:Entry[] entries = check zip:listEntries("./reports.zip");
    foreach zip:Entry entry in entries {
        io:println(entry.name, " ", entry.uncompressedSize);
    }

    check zip:decompress("./reports.zip", "./restored", {
        limits: {maxEntries: 1000, maxTotalSize: 100 * 1024 * 1024}
    });
}
```

### Step 3: Work entry by entry

Use `ArchiveWriter` and `ArchiveReader` when the archive is assembled from more than one source, or when only a part of it is needed.

```ballerina
zip:ArchiveWriter writer = check new ("./bundle.zip", {level: zip:BEST});
check writer.addFile("./summary.pdf");
check writer.addEntry("notes.txt", "shipped on 2026-08-16".toBytes());
check writer.close();

zip:ArchiveReader archive = check new ("./bundle.zip");
byte[] notes = check archive.readEntry("notes.txt");
check archive.close();
```

### Step 4: Run the Ballerina application

```bash
bal run
```

## Examples

The `zip` library provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerina-zip/tree/main/examples).

1. [Unpack an Untrusted Archive](https://github.com/ballerina-platform/module-ballerina-zip/tree/main/examples/unpack-untrusted-archive): Unpacks an archive that came from outside the system. Caps what the extraction is allowed to cost with `ExtractionLimits`, and tells a hostile archive from a broken one by the error type it gets back.

2. [Rewrite an Archive](https://github.com/ballerina-platform/module-ballerina-zip/tree/main/examples/rewrite-an-archive): Adds an entry to and removes an entry from an archive, which a ZIP cannot do in place. Carries the entries that stay across with `copyEntry`, exactly as they are stored.

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Export a GitHub personal access token with read package permissions as follows:

    ```bash
    export packageUser=<Username>
    export packagePAT=<Personal access token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To run tests against different environments:

   ```bash
   ./gradlew clean test -Pgroups=<Comma separated groups/test cases>
   ```

5. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

8. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
