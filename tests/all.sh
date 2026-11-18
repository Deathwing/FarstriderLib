#!/bin/bash
# Every test. Exit 1 on any failure.
cd "$(dirname "$0")/.." || exit 1
fail=0
for t in toc anniversary; do
    if luajit "tests/$t.lua"; then
        echo "$t ok"
    else
        echo "$t FAILED"
        fail=1
    fi
done
exit $fail
