#!/bin/bash

set -e  # exit on a non-zero return code from a command
set -x  # print a trace of commands as they execute

if ! [ -x "$(command -v protoc)" ]; then
  echo 'Error: protoc is not installed.' >&2
  echo 'install protoc: brew install swift-protobuf'
  exit 1
fi

mkdir -p Sources/CRDT/Generated

protoc \
    --swift_opt=Visibility=Public \
    --swift_out=Sources/CRDT/Generated Protos/*.proto
#    --swift_opt=FileNaming=[DropPath] \
