# Ballerina Zip connector

[![Build](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-zip/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerina-zip.svg)](https://github.com/ballerina-platform/module-ballerina-zip/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/module-ballerina-zip.svg?label=Open%20Issues)](https://github.com/ballerina-platform/module-ballerina-zip/issues)

## Overview

[//]: # (TODO: Add an overview describing the purpose of the connector and the operations it supports.)

The `ballerina/zip` connector provides APIs to create and extract ZIP archives from Ballerina.

## Quickstart

[//]: # (TODO: Add a quickstart demonstrating a basic operation, with sample code snippets.)

To use the `zip` connector in your Ballerina application, update your `.bal` file as follows.

### Step 1: Import the module

```ballerina
import ballerina/zip;
```

### Step 2: Invoke the connector operations

### Step 3: Run the Ballerina application

```bash
bal run
```

## Examples

The `zip` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerina-zip/tree/main/examples).

[//]: # (TODO: Add examples)

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
