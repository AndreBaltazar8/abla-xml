# Changelog

## 0.1.0

- Add a deterministic XML writer: escaping, four output encodings, namespaces, and
  checks that nothing ill-formed gets written.
- Add a bounded, non-validating XML 1.0 (Fifth Edition) parser with namespaces, CDATA,
  position-aware errors, internal DTD handling behind an option, and no external entities.
- Run the W3C conformance suite, xmllint, expat and fuzzing in CI.
