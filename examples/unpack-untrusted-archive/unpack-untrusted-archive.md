# Unpack an Untrusted Archive

## Introduction

This guide demonstrates how to unpack a ZIP archive that came from outside the system using the Ballerina `zip` library. An archive states how large each of its entries is, but nothing checks that claim until the entry is unpacked. The workflow covers capping what an extraction is allowed to cost with `ExtractionLimits`, and telling a hostile archive from a broken one by the error `decompress` returns.

The example unpacks two archives from `resources/` through the same call: an ordinary one, and one built to expand far past the space it takes up on disk.

## Run the example

Execute the following command to run the example.

```bash
bal run
```
