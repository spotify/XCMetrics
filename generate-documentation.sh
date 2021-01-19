#!/bin/bash

#
# Generates the documentation for the project
#

set -e

if [ -d docs_temp ] ; then
    rm -rf docs_temp
fi

mkdir docs_temp

sourcekitten doc --spm-module XCMetricsBackendLib > docs_temp/backend_docs.json
sourcekitten doc --spm-module XCMetricsClient > docs_temp/client_docs.json

jazzy

rm -rf docs_temp

