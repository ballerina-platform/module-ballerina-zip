#!/bin/bash

# Set script to exit immediately on error
set -e

# Define directories
BAL_EXAMPLES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAL_REPO_DIR="$(cd "$BAL_EXAMPLES_DIR/.." && pwd)"
BAL_REPO_NAME="$(basename "$BAL_REPO_DIR")"
BAL_HOME_DIR="$BAL_REPO_DIR/ballerina"
BAL_CENTRAL_DIR="$HOME/.ballerina/repositories/central.ballerina.io"

# Validate input command
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <build|run>"
  exit 1
fi

case "$1" in
  build)
    BAL_CMD="build"
    ;;
  run)
    BAL_CMD="run"
    ;;
  *)
    echo "Invalid command provided: '$1'. Please provide 'build' or 'run' as the command."
    exit 1
    ;;
esac

# Read Ballerina package name from Ballerina.toml
if [[ ! -f "$BAL_HOME_DIR/Ballerina.toml" ]]; then
  echo "Error: Ballerina.toml not found in $BAL_HOME_DIR"
  exit 1
fi
BAL_PACKAGE_NAME=$(awk -F'"' '/^name/ {print $2}' "$BAL_HOME_DIR/Ballerina.toml")

# This package sets `isConnector = true`, so the Ballerina Gradle plugin builds the module inside the
# `ballerina/ballerina` image rather than with the host `bal`. Every `bal` invocation here goes
# through the same image, for the same two reasons the plugin does it:
#
#   - the distribution is the one pinned in `gradle.properties`, so packing the module does not
#     rewrite `Dependencies.toml` the way a mismatched host `bal` would, and
#   - the module is packed and pushed under the paths it was built with, so its platform
#     dependencies are found where the bala says they are.
if ! command -v docker > /dev/null 2>&1; then
  echo "Error: docker is required to build the examples, as it is to build the module."
  exit 1
fi

# The image tag is resolved the way the Gradle plugin resolves it: the pinned language version,
# except that a timestamped version is only published as `nightly`.
BAL_LANG_VERSION=$(awk -F= '/^ballerinaLangVersion[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2}' \
  "$BAL_REPO_DIR/gradle.properties")
if [[ -z "$BAL_LANG_VERSION" ]]; then
  echo "Error: ballerinaLangVersion not found in $BAL_REPO_DIR/gradle.properties"
  exit 1
fi
if [[ "$BAL_LANG_VERSION" == *-* ]]; then
  BAL_IMAGE="ballerina/ballerina:nightly"
else
  BAL_IMAGE="ballerina/ballerina:$BAL_LANG_VERSION"
fi

# The repository is mounted where the Gradle plugin mounts it, so the build caches the module build
# left behind stay valid.
BAL_CONTAINER_DIR="/home/ballerina/$BAL_REPO_NAME"

# `bal` reads and writes the repositories under `~/.ballerina`, which is where the module is pushed
# and where the examples then resolve it from. It is mounted rather than left inside the container so
# that it survives the container, and HOME is set because the container runs under a UID the image
# has no passwd entry for.
mkdir -p "$HOME/.ballerina"

run_bal() {
  local workdir="$1"
  shift
  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -e HOME=/home/ballerina \
    -v "$BAL_REPO_DIR":"$BAL_CONTAINER_DIR" \
    -v "$HOME/.ballerina":/home/ballerina/.ballerina \
    -w "$BAL_CONTAINER_DIR/$workdir" \
    "$BAL_IMAGE" bal "$@"
}

# The plugin runs its container as root, so what the module build wrote into the tree is owned by
# root on the host and a `bal` running as anyone else cannot clean it. Hand it back before packing.
echo "Restoring ownership of what the module build left behind..."
docker run --rm -u root \
  -v "$BAL_REPO_DIR":"$BAL_CONTAINER_DIR" \
  "$BAL_IMAGE" chown -R "$(id -u):$(id -g)" "$BAL_CONTAINER_DIR"

# Push the package to the local repository
echo "Packing and pushing the Ballerina package..."
run_bal ballerina pack || exit 1
run_bal ballerina push --repository=local || exit 1

# Remove cache directories in the central repository
echo "Cleaning cache directories in the central repository..."
while IFS= read -r -d '' dir; do
  if [[ -d "$dir" ]]; then
    rm -rf -- "$dir"
    echo "Removed cache directory: $dir"
  fi
done < <(find "$BAL_CENTRAL_DIR" -type d -name "cache-*" -print0 2>/dev/null)
echo "Successfully cleaned the cache directories."

# Create the package directory in the central repository
echo "Updating the central repository..."
BAL_DESTINATION_DIR="$BAL_CENTRAL_DIR/bala/ballerina/$BAL_PACKAGE_NAME"
BAL_SOURCE_DIR="$HOME/.ballerina/repositories/local/bala/ballerina/$BAL_PACKAGE_NAME"
mkdir -p "$BAL_DESTINATION_DIR"
if [[ -d "$BAL_DESTINATION_DIR" ]]; then
  rm -r "$BAL_DESTINATION_DIR"
fi
if [[ -d "$BAL_SOURCE_DIR" ]]; then
  cp -r "$BAL_SOURCE_DIR" "$BAL_DESTINATION_DIR"
  echo "Successfully updated the local central repository."
else
  echo "Warning: Source directory $BAL_SOURCE_DIR does not exist."
fi

echo "Source Directory: $BAL_SOURCE_DIR"
echo "Destination Directory: $BAL_DESTINATION_DIR"

# Loop through examples in the examples directory and execute the command
echo "Processing examples in the examples directory..."
while IFS= read -r -d '' dir; do
  # Skip the build directory
  if [[ "$(basename "$dir")" == "build" ]]; then
    continue
  fi
  echo "Processing example: $dir"
  run_bal "examples/$(basename "$dir")" "$BAL_CMD"
done < <(find "$BAL_EXAMPLES_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

# Remove generated JAR files in the Ballerina home directory
echo "Cleaning up generated JAR files..."
find "$BAL_HOME_DIR" -maxdepth 1 -type f -name "*.jar" -exec rm {} \;
echo "Successfully removed generated JAR files."

echo "Script execution completed successfully."
