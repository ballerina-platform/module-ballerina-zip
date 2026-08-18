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
