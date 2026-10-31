# abla-xml

XML for Abla: a deterministic writer and a bounded, safe parser, with no dependencies
beyond the standard library, and which read or write nothing but what they are given. It implements XML 1.0 (Fifth Edition) and
Namespaces in XML 1.0, as a non-validating processor.

```abla
import github("AndreBaltazar8/abla-xml")
import "abla/io"

fun main: int {
    val w = xmlWriter(XmlWriterOptions(indent = "  "))
    w.declaration()
    w.startElement("Invoice")
    w.namespace("", "urn:example:invoice")
    w.attribute("id", "FT 1/2")
    w.element("Customer", "Ana & Filhos")
    w.endElement()
    val written = w.finish()
    if (!written.succeeded) {
        eprintln(written.errorMessage)
        return 1
    }
    println(written.text)

    val parsed = xmlParse(written.text)
    val document = parsed.document
    if (document != null) println(document.root.childText("Customer"))
    0
}
```

## Writer

The same calls always give the same bytes. Nothing is reordered, sorted or invented:
attributes, namespace declarations and children appear in the order they were
written, and there are no generated prefixes.

| Call | Effect |
|---|---|
| `xmlWriter(XmlWriterOptions(encoding = "UTF-8", indent = ""))` | a new writer |
| `w.declaration(standalone = "")` | the XML declaration, first if at all |
| `w.startElement(qname)` | opens an element |
| `w.namespace(prefix, uri)` | declares a prefix (`""` is the default namespace) on the element just opened |
| `w.attribute(qname, value)` | an attribute on the element just opened |
| `w.text(value)`, `w.cdata(value)` | character data |
| `w.comment(value)`, `w.processingInstruction(target, data = "")` | comment or instruction |
| `w.endElement()` | closes the innermost element, as `<a/>` when it is empty |
| `w.element(qname, value = "")` | `startElement`, `text`, `endElement` |
| `w.finish()` | an `XmlWriteResult`: `succeeded`, `text`, `errorCode`, `errorMessage`, `bytesWritten` |
| `xmlWriteElement(w, element)`, `xmlWriteDocument(w, document)` | writes a parsed tree |

Errors are sticky, so a sequence of calls needs one check, at `finish()`. Nothing
invalid can be written: names, characters (invalid UTF-8, control characters, U+FFFE),
comments, instructions, duplicate attributes (also by expanded name), undeclared
prefixes, reserved namespaces, misplaced calls and unbalanced elements are all errors.

- Text escapes `&`, `<` and `>`, plus a carriage return, which a parser would otherwise
  turn into a line feed.
- Attribute values also escape `"`, tab and line feed, which a parser would otherwise
  turn into spaces.
- A `]]>` in `cdata` is split over two sections, and a carriage return goes between two.
- `encoding` is `UTF-8`, `US-ASCII`, `ISO-8859-1` or `windows-1252`. The declaration
  spells it as given. A character the encoding lacks becomes a hexadecimal character
  reference in text and attribute values, and the error `unencodable_char` in names,
  comments, instructions and CDATA. UTF-16 is read but not written.
- `indent` is spaces or tabs. An element holding text keeps its content on one line, so
  indentation never changes a text node. Output ends in a line feed only when indenting.

### Writing as you go

`xmlStreamWriter(sink, options)` is the same writer, with the same calls, errors and bytes,
that gives its encoded output to `sink` instead of keeping it. It holds about
`XmlWriterOptions.flushBytes` (64 KiB) of output and what the open elements need.

```abla
val w = xmlStreamWriter(xmlFileSink(path("big.xml")))
w.startElement("rows")
for (row in rows) w.element("row", row)
w.endElement()
val written = w.finish()      // written.bytesWritten; written.text is empty
```

A sink is an `XmlSink`: `write(bytes)` returning false for the error `sink_failed`, and
`close()`, which `finish()` calls once, also after an error. `xmlFileSink(path)` writes a file,
and `xmlCallbackSink(function)` takes a plain function. A sink that keeps state of its own is
a class implementing `XmlSink`, because a closure that changes a capture can't be stored. An
error can come after the sink has had a part of the document: discarding it is the caller's.

Those calls are the API meant to stay stable. There is no visibility for class members
in Abla, so the writer's other methods are visible; they are not part of it.

## Parser

`xmlParse(source, options = XmlOptions())` gives an `XmlParseResult`: `succeeded`,
`document`, `error`. `source` is the document's bytes.

`XmlDocument` has `root`, `prolog`, `epilog`, `version`, `encoding`, `standalone`,
`doctype` and `skippedEntities`. Nodes are the sealed `XmlNode`: `XmlElement`, `XmlText`
(with `cdata`), `XmlComment`, `XmlProcessingInstruction`, `XmlSkippedEntity`.

`XmlElement` has `name`, `prefix`, `localName`, `namespaceUri`, `attributes`, `children`,
`byteOffset`, `line`, `column`, and:

| Method | Result |
|---|---|
| `attribute(localName, namespaceUri = "")` | the `XmlAttribute`, or null |
| `attributeValue(localName, fallback = "", namespaceUri = "")` | its value, or `fallback` |
| `child(localName, namespaceUri = xmlAnyNamespace)` | the first such child element, or null |
| `elements(localName = xmlAnyNamespace, namespaceUri = xmlAnyNamespace)` | child elements |
| `text()` | all the text inside, in document order |
| `childText(localName, namespaceUri = xmlAnyNamespace)` | the first such child's text, or `""` |

For large documents, `xmlReader(source, options)` gives events without building a tree:
`next()` returns an `XmlEvent` whose `kind` is `xmlEventStart`, `xmlEventEnd`,
`xmlEventText`, `xmlEventCdata`, `xmlEventComment`, `xmlEventProcessingInstruction`,
`xmlEventSkippedEntity`, `xmlEventEndOfDocument` or `xmlEventError` (then `reader.error`).

### Reading from a source

`xmlChunkedReader(source, options)` is that reader without the whole document in memory. It
pulls `chunkBytes` (64 KiB) at a time from an `XmlSource` and keeps a window of it, which is
at most `maxWindowBytes` (64 MiB), and only as much as the longest token needs.

```abla
val r = xmlChunkedReader(xmlFileSource(path("big.xml")),
    XmlOptions(maxBytes = 1099511627776, maxNodes = 1099511627776))
while (true) {
    val event = r.next()
    if (event.kind == xmlEventEndOfDocument || event.kind == xmlEventError) break
    // ...
}
```

An `XmlSource` has `read(maximum)`, with `""` for the end, and `failure()` and `close()`, with
defaults; a failure is the error `source_failed`. `xmlFileSource(path)` reads a file, and
`xmlStringSource(text, pieceBytes)` a string. The reader closes it at the end of the document
and on an error; one who stops reading earlier calls `reader.closeSource()`.

The events are those of `xmlReader`, including every offset, line and column, however the
bytes are split; tests compare the two on the whole W3C suite and in fuzzing. It differs where
a document can't be judged before it has arrived:

- Events before a problem come first. An invalid byte, or going over `maxBytes`, is found when
  the reader gets there, so a well-formedness error earlier in the document is reported instead
  of it. `xmlReader` checks those before its first event.
- `value_too_long` for text is reported when the limit is passed, not at the end of the text.
- An error about the bytes of an encoding gives an offset in the decoded text and a real line
  and column, where `xmlReader` gives the offset in the source and 1:1.

`xmlParse` and `xmlReader` still take a whole string.

Errors are `XmlError`: `code`, `message`, `byteOffset`, `line`, `column`, `entity`.
Columns count characters; a problem inside an entity is reported at the reference to it.
In a document that isn't UTF-8, `byteOffset` counts the decoded UTF-8 text.

Encodings read: UTF-8, UTF-16 with a byte order mark, US-ASCII, ISO-8859-1 and
windows-1252. Any other declared encoding is the fatal `unsupported_encoding`, as XML 1.0
section 4.3.3 requires of an encoding a processor can't read.

### Safety

- **No I/O of its own.** The parser takes a string or a source its caller made. External DTD subsets and external entities are
  never read: a reference to one in content becomes an `XmlSkippedEntity` node and counts
  in `skippedEntities`, and declarations after an unread parameter entity are not used.
  Check `skippedEntities` if content must be complete.
- **No DTD by default.** A `DOCTYPE` is the error `dtd_forbidden` unless
  `XmlOptions(allowDtd = true)`.
- **No expansion attacks.** With a DTD, each expansion counts against `maxEntityExpansions`
  (4096), `maxEntityBytes` (1 MiB, summed over the document, so repetition is caught as
  well as nesting) and `maxEntityDepth` (16). Recursion is an error.
- **Everything else is bounded**: `maxBytes` (64 MiB), `maxDepth` (256), `maxNodes`,
  `maxAttributes`, `maxNameBytes`, `maxValueBytes`, `maxNamespaces`. The reader itself
  doesn't recurse on element depth. `XmlElement.text()` and the tree writer do, so raising
  `maxDepth` far beyond the default is for the reader only.

- **With a source, the bound holds on the document as well.** `maxBytes` and `maxNodes` still
  apply, with the same defaults, so a big document asks for more by name. A single token (a tag
  with all its attributes, a comment, CDATA, an instruction, a reference, or the whole DOCTYPE
  with every declaration in it) must fit `maxWindowBytes`, or it is the error `token_too_long`;
  `value_too_long` comes first for a comment, CDATA or instruction over `maxValueBytes`. Text can
  be longer than the window up to `maxValueBytes`. Names and namespaces kept for open elements
  also count against `maxWindowBytes`, as `state_too_large`. So what a reader holds is at most
  about `maxWindowBytes` + `maxValueBytes`, plus the garbage collector's slack, on any input.

Work is linear in the input size. On the development machine the reader does about 16 MB/s on a
typical document with events only and 6 MB/s building a tree (about 18 MB/s from a file); the worst input found, the
most namespace lookups the limits allow, took 17 s for 54 MB. Lower `maxBytes` where
hostile input is expected.

## Conformance

`make conformance` downloads the [W3C XML conformance
suite](https://www.w3.org/XML/Test/) (xmlts20130923, checked by hash, not stored in this
repository because of its mixed copyrights) and runs every test in its catalogs. Results
on 2026-10-31:

| Type | Tests | Out of scope | Passed | Failed | Accepted, error external |
|---|---:|---:|---:|---:|---:|
| not-wf (must be rejected) | 1498 | 481 | 958 | 0 | 59 |
| valid (must be accepted) | 812 | 84 | 728 | 0 | 0 |
| invalid (must be accepted: this parser doesn't validate) | 242 | 13 | 229 | 0 | 0 |
| error (either outcome passes) | 32 | 6 | 26 | 0 | 0 |
| **All** | 2584 | 584 | 1941 | 0 | 59 |

What the numbers mean:

- **Out of scope**: 273 tests in the XML 1.1 and Namespaces 1.1 catalogs, and 311 others
  marked for XML 1.1 or for editions before the fifth, mostly IBM name tests that the
  fifth edition's broader name rules make well-formed.
- **Accepted, error external**: not-wf tests whose error isn't found, and that declare
  they use external entities. This parser doesn't read those on purpose, so these 59 can't
  pass. `xmllint --nonet`, not loading external entities either, accepts all 59 too. A
  not-wf test that uses no external entities and is accepted counts as a failure.
- **Passed, with external entities unread**: 181 of the passing valid and invalid tests
  (127 and 54) have external entities whose content wasn't read, so those passes say
  nothing about that content. `make conformance` prints how many per group.
- **Output checks**: 249 of the valid and invalid tests also give the expected canonical
  output, which is compared byte for byte, and all match. Tests whose output needs
  external entities or the notations of the second canonical form aren't compared.
- The 6 Japanese tests in `error` are in EUC-JP, Shift_JIS and ISO-2022-JP, and are
  rejected as `unsupported_encoding`. The suite allows this, but it is not support.
- The `error` type counts as passed either way, so its 26 passes prove only no crash.

## Other tests

- `make unit`: writer and parser unit tests; a property test of 2000 generated documents
  that must read back to what the generator recorded, and rewrite stably.
- `make written`: the same 2000 documents through `xmllint`, and through expat
  (`tools/check-written.py`), which must see exactly the events the generator recorded,
  in each of the four encodings.
- `make fuzz`: repeatable mutational fuzzing from built-in seeds and the suite's small
  files. Each input is parsed under four sets of options; no panic, errors have sane
  positions, and what parses must write and reparse to the same meaning. CI runs 200,000
  inputs.
- `make conformance` and `make fuzz` also put every file and fuzz input through the chunked
  reader in pieces of a few sizes, down to one byte, against the whole-string reader: same
  events, same errors, except as listed under [Reading from a source](#reading-from-a-source).
- `make big`: local only, not in CI. A document of at least 3 GiB written and read back through
  files, and through `xmllint --stream`. On 2026-10-31, 3,300,063,677 bytes in Windows-1252:
  writing peaked at 181 MB of memory in 36 s, reading at 258 MB in 179 s (102 million text
  nodes), and xmllint found it well-formed. At 300 MB the same programs peak at 180 MB and 256 MB,
  so the peak doesn't grow with the document: most of it is garbage awaiting the default 64 MiB
  collection threshold (`memorySetCollectionGrowth` lowers it).
- `make differential`: prints where this parser and xmllint disagree on fuzz inputs. Not
  a pass/fail check.

Run them with `nix-shell ../ablac/shell.nix --run 'make all'`, adding `libxml2` and
`python3` for `written`.

## Not here

Validation, XML Schema, XPath, XML 1.1, external entity loading, and writing a DOCTYPE or
UTF-16. `xmlParse` needs memory for the whole tree; use `xmlChunkedReader` when that is too much.

## License

[Mozilla Public License 2.0](LICENSE). This package is meant to move into the Abla standard
library once its API has settled.
