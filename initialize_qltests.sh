#!/bin/sh

# This script copies Exercise#.c files from the
# solutions-tests directory to the appropriate sub-directories
# in the exercises-tests QLTest directories.
[[ $(git rev-parse --show-toplevel) == $(pwd) ]] || {
    echo "This script must be run from the root of the workshop repository."
    exit 1
}

SRCDIR=$(pwd)/solutions-tests

target_dirs=(
    $(pwd)/exercises-tests
)

for dir in "${target_dirs[@]}"; do
    for i in {1..6}; do
        cp $SRCDIR/Exercise$i/test.c $dir/Exercise$i/test.c
    done
done

exit 0