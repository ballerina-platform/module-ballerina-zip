# Examples

The `zip` library provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerina-zip/tree/main/examples).

1. [Unpack an archive you did not create](unpack-untrusted-archive) - Unpack an archive from outside the system under `ExtractionLimits`, and tell a hostile archive from a broken one.
2. [Add to and remove from an archive](rewrite-an-archive) - Rewrite an archive with `copyEntry`, keeping the entries that stay exactly as they are stored.

## Prerequisites

1. Follow the [instructions](https://github.com/ballerina-platform/module-ballerina-zip#build-from-the-source) to build the package from the source.

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
