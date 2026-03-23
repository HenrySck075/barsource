#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}/native"

if [ ! -d "build" ]; then
    mkdir build
    cd build
    cmake ..
else
    cd build
fi

cmake --build .

find . -name "*.so" -exec cp {} "${SCRIPT_DIR}/dart/blob/" \;

cd "${SCRIPT_DIR}"
dart run "$1"
