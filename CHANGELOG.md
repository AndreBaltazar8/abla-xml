# Changelog

## Unreleased

- Assertions: `=` and `!=` over strings and untyped values compare in linear time (a set of one side's texts), an expression
  nests at most 128 levels (`xsdXpathMaxDepth`: 10,000 open parentheses, `not(` or `if` in a schema ended the process with a
  stack overflow), and an `or` / `and` chain is evaluated with a stack of its own (a chain of 10,000 operands overflowed).
- `tools/xsd-security.ab`: what an untrusted schema or instance can make the validator do (cycles, includes, content-model
  size, type chains, value parsing, XPath depth and length, assertion and identity-constraint cost), in `make security`.
- `XsdOptions.maxAssertionWork` (25,000,000): the pairs of values the general comparisons of assertions compare, in all of a
  document. `not(c = d)` over N and N values that never match cost N * N (30,000 each: 63 s for a 1 MB document); past the
  limit the assertions that need a comparison fail with that reason.
- `xmlWriteElement` no longer recurses per level: a tree a million levels deep (a reader with `maxDepth` raised) is written
  without a stack overflow (it overflowed from about 20,000 levels).
- `tools/security.ab` and `make security`: every `XmlOptions` limit checked at its boundary, the entity limits, the XSD
  regex's cost, the writer's escaping through the parser (400,000 random values), and the decoders against Unicode's
  tables (every 1- to 3-byte UTF-8 sequence, every UTF-16 unit, every windows-1252 byte).

## 0.3.0

- Add XML Schema validation, `import github("AndreBaltazar8/abla-xml/xsd")`: `xsdLoad`, `xsdValidate`,
  `xsdValidateSource`. XSD 1.1 with assertions in a subset of XPath 2.0, repeating `xs:all`, identity
  constraints and every facet, streaming, and bounded; what it doesn't implement is refused when the
  schema loads. See the README for what is in and what is out.
- Reading Windows-1252, ISO-8859-1 or US-ASCII takes runs of ASCII at once: a 126 MB file reads in
  4.9 s instead of 8.2.

## 0.2.0

- Add `xmlStreamWriter(sink, options)`: the writer's bytes go to an `XmlSink` as they are
  encoded, with `xmlFileSink` and `xmlCallbackSink`. The string writer gives the same bytes.
- Add `xmlChunkedReader(source, options)`: events from an `XmlSource`, holding a bounded window,
  with `xmlFileSource` and `xmlStringSource`, and the options `maxWindowBytes` and `chunkBytes`.
- Fix a skipped entity with text before it: its event came after whatever followed it (an
  element, or more text, whose end also gave its position), and now comes straight after the text.
- Writing to a non-UTF-8 encoding no longer goes byte by byte over names that are ASCII.

## 0.1.0

- Add a deterministic XML writer: escaping, four output encodings, namespaces, and
  checks that nothing ill-formed gets written.
- Add a bounded, non-validating XML 1.0 (Fifth Edition) parser with namespaces, CDATA,
  position-aware errors, internal DTD handling behind an option, and no external entities.
- Run the W3C conformance suite, xmllint, expat and fuzzing in CI.
