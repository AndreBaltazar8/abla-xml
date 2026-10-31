#!/usr/bin/env python3
"""Compares this parser's verdicts on fuzz inputs (fuzz's dump directory) with
xmllint's, without loading anything external. Disagreements are for a person to
read: this parser reads fewer encodings, and xmllint's namespace errors aren't
fatal. Takes the dump directory."""
import collections
import pathlib
import subprocess
import sys


def main():
    directory = pathlib.Path(sys.argv[1])
    counts = collections.Counter()
    disagreements = []
    for line in (directory / "verdicts.txt").read_text().split("\n"):
        if not line:
            continue
        name, verdict = line.split()
        path = directory / (name + ".xml")
        run = subprocess.run(
            ["xmllint", "--noout", "--nonet", "--huge", str(path)], capture_output=True
        )
        theirs = "accept" if run.returncode == 0 else "reject"
        if theirs == verdict:
            counts["agree: " + verdict] += 1
        else:
            counts["we %s, xmllint %ss" % (verdict, theirs)] += 1
            first = run.stderr.decode("latin1").split("\n")[0][:160]
            disagreements.append("%s: we %s; %s" % (path, verdict, first))
    print(dict(counts))
    for disagreement in disagreements:
        print(disagreement)


main()
