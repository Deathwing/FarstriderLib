#!/bin/sh
# Run luajit tests under Preflight's strict_api for retail and Forever, with
# loadDeprecationFallbacks on and off. Prints only failures and one summary line.
set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PF="${PREFLIGHT:-/Users/jeffmlr/Projects/firstmate/projects/Preflight}"
if [ ! -f "$PF/tools/strict_api.lua" ]; then
    echo "strict: no Preflight at $PF, skipped"
    exit 0
fi
fail=0
count=0
for client in retail forever; do
    for fb in "" 0; do
        for test in toc anniversary; do
            count=$((count + 1))
            if [ "$fb" = "0" ]; then
                out=$( ( CDPATH= cd -- "$HERE" && STRICT_CLIENT="$client" STRICT_FALLBACKS=0 PREFLIGHT="$PF" luajit "tests/${test}.lua" ) 2>&1) || {
                    fail=1
                    printf '%s\n' "$out" | grep -E '^(FAIL|strict_api:|strict:|luajit:|.*error:|.*Error)' || printf '[strict %s fb=0] tests/%s.lua\n' "$client" "$test"
                }
            else
                out=$( ( CDPATH= cd -- "$HERE" && STRICT_CLIENT="$client" STRICT_FALLBACKS= PREFLIGHT="$PF" luajit "tests/${test}.lua" ) 2>&1) || {
                    fail=1
                    printf '%s\n' "$out" | grep -E '^(FAIL|strict_api:|strict:|luajit:|.*error:|.*Error)' || printf '[strict %s fb=on] tests/%s.lua\n' "$client" "$test"
                }
            fi
        done
    done
done
[ "$fail" -eq 0 ] && echo "strict tests ok ($count runs)" || echo "strict tests FAILED"
exit "$fail"
