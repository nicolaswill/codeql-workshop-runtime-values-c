#!/bin/bash
SRCDIR=$(pwd)/session-db
DB=$SRCDIR/cpp-runtime-values-db
codeql database create --language=cpp -s "$SRCDIR" -j 8 -v $DB --command="clang -fsyntax-only -Wno-unused-value $SRCDIR/DB/db.c"
