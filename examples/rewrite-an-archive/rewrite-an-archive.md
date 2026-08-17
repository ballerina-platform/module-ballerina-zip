# Rewrite an Archive

## Introduction

This guide demonstrates how to add an entry to and remove an entry from a ZIP archive using the Ballerina `zip` library. A ZIP keeps its index of entries at the end of the file, so no entry can be added or removed in place and the archive has to be written out afresh. The workflow covers carrying the entries that stay across with `copyEntry`, which moves them exactly as they are stored rather than decompressing and compressing them again, leaving one entry out, adding a new one, and reading the result back.

## Run the example

Execute the following command to run the example.

```bash
bal run
```
