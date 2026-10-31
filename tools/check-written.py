#!/usr/bin/env python3
"""Checks write-corpus output with expat, a parser that shares nothing with this
library: each document must parse, in its declared encoding, to exactly the events
the generator recorded. Takes the corpus directory."""
import pathlib
import sys
from xml.parsers import expat


def key(name):
    if " " in name:
        uri, local = name.split(" ", 1)
        return "{%s}%s" % (uri, local)
    return "{}" + name


def describe(data):
    lines = []
    text = []

    def flush():
        if text:
            lines.append("T " + "".join(text).encode().hex())
            text.clear()

    def start(name, attributes):
        flush()
        lines.append("S " + key(name))
        pairs = sorted((key(k), v) for k, v in attributes.items())
        pairs.sort(key=lambda pair: pair[0].encode())
        for k, v in pairs:
            lines.append("A %s %s" % (k, v.encode().hex()))

    def end(_name):
        flush()
        lines.append("E")

    def comment(value):
        flush()
        lines.append("C " + value.encode().hex())

    def instruction(target, value):
        flush()
        lines.append("P %s %s" % (target, value.encode().hex()))

    parser = expat.ParserCreate(namespace_separator=" ")
    parser.buffer_text = False
    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.CharacterDataHandler = text.append
    parser.CommentHandler = comment
    parser.ProcessingInstructionHandler = instruction
    parser.Parse(data, True)
    return "\n".join(lines) + "\n"


def main():
    directory = pathlib.Path(sys.argv[1])
    documents = sorted(directory.glob("*.xml"))
    failures = 0
    for path in documents:
        try:
            actual = describe(path.read_bytes())
        except expat.ExpatError as error:
            print("%s: expat rejects it: %s" % (path, error))
            failures += 1
            continue
        if actual != path.with_suffix(".expected").read_text(encoding="utf-8"):
            print("%s: means something else to expat" % path)
            failures += 1
    print("expat: %d documents, %d failures" % (len(documents), failures))
    return 1 if failures else 0


sys.exit(main())
