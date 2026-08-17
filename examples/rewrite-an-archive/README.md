# Add to and remove from an archive

A ZIP file cannot be changed once it is written. Its index of entries sits at the end of the file, so adding or removing one entry means rewriting the index, and there is no way to do that in place. Every tool that appears to edit an archive is writing a new one.

`copyEntry` is what makes that cheap. It carries an entry from one archive into another exactly as it is stored, without decompressing and recompressing it:

```ballerina
zip:ArchiveReader existing = check new ("./resources/quarterly.zip");
zip:ArchiveWriter rebuilt = check new ("./quarterly-final.zip", {overwrite: true});

foreach zip:Entry entry in check existing.entries() {
    if entry.name == "drafts/notes.txt" {
        continue;                                  // left out of the new archive
    }
    check rebuilt.copyEntry(existing, entry.name); // kept, exactly as stored
}
check rebuilt.addEntry("reports/release.txt", released.toBytes());
check rebuilt.close();
```

## Run the example

```bash
bal run
```

```
copied   reports/ (directory)
copied   reports/region-totals.csv (deflated)
copied   reports/summary.txt (deflated)
copied   reports/logo.png (stored)
dropped  drafts/notes.txt
added    reports/release.txt

./quarterly-final.zip holds:
  reports/ (directory) crc 0
  reports/region-totals.csv (deflated) crc 391d2603
  reports/summary.txt (deflated) crc bc3871c1
  reports/logo.png (stored) crc 90c4732e
  reports/release.txt (deflated) crc e9be5734

still holds 'drafts/notes.txt': false
```

The checksums of the copied entries are those of the source archive, and `logo.png` is still stored rather than deflated. That is the point of `copyEntry`: nothing was decoded, so nothing could change. The writer's `level` applies only to `reports/release.txt`, the one entry that was actually compressed here.

An entry this library cannot read can still be copied, since the bytes are never examined. The exception is an encrypted entry, which gives an `UnsupportedEntryError`: carrying the bytes across would mean writing a header that says the content is plain over content that is not.

## Things worth knowing

**Order is yours to choose.** Entries are written in the order you add them, so you can reorder while rewriting.

**Names are matched to the first entry that has them.** A ZIP may hold two entries with the same name; `copyEntry` takes the first. Copying in a loop over `entries()` therefore writes the first entry twice and never the second. Archives like this are malformed, but they exist.

**`overwrite` is set here** so the example can be run more than once. Without it, a writer refuses to replace a file already at its path.

**Nothing is left behind on failure.** The new archive is not a valid ZIP until `close` writes its index, so if the rewrite fails part way, what remains is an unreadable file rather than a plausible-looking archive with entries missing. Write to a temporary path and move it into place when the original must survive a failure.
