#!/usr/bin/env bash
# Checks write-corpus output with libxml2, a parser that shares nothing with this library: xmllint reads each document
# and writes its canonical form (C14N, UTF-8), and tools/check-written.ab compares what this library reads from that
# with the events the generator recorded. Takes the checker's binary and the corpus directory; needs xmllint.
set -euo pipefail
checker=$1
directory=$2
for document in "$directory"/*.xml; do
    xmllint --nonet --encode UTF-8 "$document" > "${document%.xml}.c14n" 2> "${document%.xml}.err" || rm -f "${document%.xml}.c14n"
done
ls "$directory"/*.expected > "$directory/list.txt"
"$checker" "$directory/list.txt"
