#!/usr/bin/env bash
# Compares this parser's verdicts on fuzz inputs (fuzz's dump directory) with xmllint's, without loading anything
# external. Disagreements are for a person to read: this parser reads fewer encodings, and xmllint's namespace errors
# aren't fatal. Takes the dump directory.
set -euo pipefail
directory=$1
declare -A counts
disagreements=()
while read -r name verdict; do
    [[ -n $name ]] || continue
    path="$directory/$name.xml"
    if xmllint --noout --nonet --huge "$path" > /dev/null 2> "$directory/xmllint.err"; then theirs=accept; else theirs=reject; fi
    if [[ $theirs == "$verdict" ]]; then
        counts["agree: $verdict"]=$(( ${counts["agree: $verdict"]:-0} + 1 ))
    else
        counts["we $verdict, xmllint ${theirs}s"]=$(( ${counts["we $verdict, xmllint ${theirs}s"]:-0} + 1 ))
        first=$(head -n 1 "$directory/xmllint.err" | cut -c1-160)
        disagreements+=("$path: we $verdict; $first")
    fi
done < "$directory/verdicts.txt"
for key in "${!counts[@]}"; do printf '%s: %s\n' "$key" "${counts[$key]}"; done | sort
for ((i = 0; i < ${#disagreements[@]}; i++)); do printf '%s\n' "${disagreements[$i]}"; done
