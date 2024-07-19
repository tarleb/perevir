#!/bin/sh

testfile=$(mktemp)
cleanup ()
{
    rm "${testfile}"
}

trap cleanup 1 2

set -e

input_file=$1
golden_file=$2

cp "$input_file" ${testfile}
pandoc-lua test/md-checker.lua -a ${testfile}
diff "$golden_file" "$testfile"
