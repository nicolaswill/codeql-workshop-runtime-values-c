SRCDIR=$(pwd)/solutions-tests/Exercise6
DB=$(pwd)/cpp-runtime-values-db
codeql database create --language=cpp -s "$SRCDIR" -j 8 -v $DB --command="clang -fsyntax-only -Wno-unused-value $SRCDIR/test.c"