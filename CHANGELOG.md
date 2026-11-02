# Changelog

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
