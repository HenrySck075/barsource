#!/bin/bash

set -e

# Get the latest release tag from GitHub API
LATEST_TAG=$(curl -s https://api.github.com/repos/HenrySck075/geode-skia/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')

if [ -z "$LATEST_TAG" ]; then
    echo "Failed to fetch latest tag"
    exit 1
fi

echo "Latest tag: $LATEST_TAG"

# Define URLs
BASE_URL="https://github.com/HenrySck075/geode-skia/releases/download/${LATEST_TAG}"
BIN_FILE="skia-Linux-bin.tar.gz"
HEADERS_FILE="skia-headers.tar.gz"

# Create target directory
TARGET_DIR="native/third_party/skia"
mkdir -p "$TARGET_DIR"

# Download files
echo "Downloading $BIN_FILE..."
curl -L -o "/tmp/$BIN_FILE" "$BASE_URL/$BIN_FILE"

echo "Downloading $HEADERS_FILE..."
curl -L -o "/tmp/$HEADERS_FILE" "$BASE_URL/$HEADERS_FILE"

# Extract files
echo "Extracting $BIN_FILE..."
tar -xzf "/tmp/$BIN_FILE" -C "$TARGET_DIR"

echo "Extracting $HEADERS_FILE..."
tar -xzf "/tmp/$HEADERS_FILE" -C "$TARGET_DIR"

# Cleanup
rm "/tmp/$BIN_FILE" "/tmp/$HEADERS_FILE"

# Rename lib directory to out/Release
mkdir -p "$TARGET_DIR/out"
mv "$TARGET_DIR/lib" "$TARGET_DIR/out/Release"

echo "Done! Skia files extracted to $TARGET_DIR"