#!/bin/bash

cd "$(dirname $0)"
DOCSRC=docgen DOCDST=source honeydipper docgen
make html
