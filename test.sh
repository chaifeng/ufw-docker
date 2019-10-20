#!/usr/bin/env bash
set -uo pipefail

function out() {
    printf "\n\e[1;37;497;m%s\e[0;m\n" "$@"
} >&2

function err() {
    printf "\n\e[1;37;41;m%s\e[0;m\n\n" "$@"
} >&2

retval=0
cd "$(dirname "${BASH_SOURCE}")"
for file in test/*.test.sh; do
    out "Running $file"
    if grep -E "^[[:blank:]]*BACH_TESTS=.+" "$file"; then
        err "Found defination of BACH_TESTS in $file"
        retval=1
    fi
    bash "$file" || retval=1
done

if [[ "$retval" -ne 0 ]]; then
    err "Test failed!"
fi

exit "$retval"
