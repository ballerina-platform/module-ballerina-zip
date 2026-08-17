# Unpack an archive you did not create

An archive says how large each entry is, but nothing checks that claim until the entry is unpacked. An archive of twenty kilobytes can become twenty megabytes, and an entry named `../../etc/passwd` can be written well outside the directory it was aimed at.

`DecompressOptions` is where that is bounded. Path safety always applies, but none of the limits below do unless you set them:

```ballerina
zip:DecompressOptions guarded = {
    fileWriteMode: zip:REPLACE,
    limits: {
        maxEntries: 500,
        maxTotalSize: 100 * 1024 * 1024,
        maxCompressionRatio: 50
    }
};
```

The example unpacks two archives from `resources/` through that same call — one ordinary, one built to expand far past the space it takes up.

## Run the example

```bash
bal run
```

```
reports unpacked into ./unpacked/reports
bomb refused: entry 'payload.bin' expands past 50 times its compressed size
```

`bomb.zip` is 20 KB on disk and holds one entry that would become 20 MB — a ratio of 1028. The limits are measured as the archive is read, so the extraction stops after about 24 KB rather than after 20 MB.

## What the errors tell you

Each guard has its own error type, so a caller can tell a hostile archive from a broken one:

| Error | Cause |
| --- | --- |
| `zip:LimitExceededError` | Too many entries, too many bytes, or one entry expanding far past what it stores |
| `zip:UnsafePathError` | An entry named so that it would be written outside the target directory |
| `zip:UnsupportedEntryError` | An entry that is encrypted, or stored with a method the library does not read |
| `zip:InvalidArchiveError` | Not a ZIP file at all |

Both `LimitExceededError` and `UnsafePathError` name the entry at fault, in the `entryName` field of the error detail.

> **Note:** When an entry breaches a limit part-way through, what had been written of it is left where it is. A caller taking in untrusted archives should discard the target directory on refusal rather than keep what got through.
