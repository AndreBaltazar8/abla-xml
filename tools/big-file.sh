#!/usr/bin/env bash
# A generated document of at least 3 GiB written and read back through files, with each
# program's peak memory, and through xmllint's streaming reader. Local only: too big and
# slow for CI. Removes its file, also on failure.
#   tools/big-file.sh <big-file program> <directory> [bytes]
set -euo pipefail
program=$1
directory=$2
bytes=${3:-3300000000}
file=$(mktemp "$directory/abla-xml-big.XXXXXX")
trap 'rm -f "$file"' EXIT
time=${TIME_BIN:-/usr/bin/time}
"$time" -f 'write: %e s, peak %M kB' "$program" write "$file" "$bytes" windows-1252
ls -l "$file"
"$time" -f 'read: %e s, peak %M kB' "$program" read "$file"
"$time" -f 'xmllint --stream: %e s, peak %M kB' xmllint --stream --noout --huge "$file"
echo 'xmllint: well-formed'
