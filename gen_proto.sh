#!/bin/sh

set -e

PATH=$PATH:./tools

rm -rf Sources/XCMetricsProto
mkdir Sources/XCMetricsProto

# Only works on macOS for now.
# TODO: add support for Linux and remove checked-in files from repo.
./tools/bin/protoc proto/xcmetrics/**/*.proto \
    --swift_out=Sources/XCMetricsProto/ \
    --swift_opt=Visibility=Public \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=Sources/XCMetricsProto/
