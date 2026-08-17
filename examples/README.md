# Examples

The `zip` library provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerina-zip/tree/main/examples).

1. [Unpack an Untrusted Archive](unpack-untrusted-archive)

   This example shows how to unpack an archive that came from outside the system. It caps what the extraction is allowed to cost with `ExtractionLimits`, and tells a hostile archive from a broken one by the error type it gets back.

2. [Rewrite an Archive](rewrite-an-archive)

   This example shows how to add an entry to and remove an entry from an archive, which a ZIP cannot do in place. It carries the entries that stay across with `copyEntry`, exactly as they are stored, leaves one out, and adds a new one.

## Running an Example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the Examples with the Local Module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala file must be published to the local repository, and the sample source code must be updated to fetch the module from the local repository.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
