#!/bin/bash
# Every test, then strict retail/Forever API guards. Prints only failures; exit 1 on any.
cd "$(dirname "$0")/.." || exit 1
fail=0
for t in toc anniversary preflight tabcomplete; do
    out=$(luajit "tests/$t.lua" 2>&1) || {
        fail=1
        echo "$out" | grep -E "^(FAIL|error|luajit|strict)" | head -20
        echo "$t FAILED"
    }
done
bash tests/strict.sh || fail=1
exit $fail
