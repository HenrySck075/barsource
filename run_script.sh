#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#cd "${SCRIPT_DIR}/dart"
#dart run ffigen

cd "${SCRIPT_DIR}/native"

if [ ! -d "build" ]; then
    mkdir build
    cd build
    cmake ..
else
    cd build
fi

cmake --build . -- -j$(nproc)

cd "${SCRIPT_DIR}/example"
dart run $* 
