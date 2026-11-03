# TODO

- [ ] Support the `xs:any namespace="##any" processContents="lax"` particle used
      by `SupplementaryDataEnvelope1` in the unchanged ISO 20022
      `pain.001.001.09` schema. The current strict loader rejects the whole schema
      at line985, including documents that never use supplementary data. Keep
      unsupported content fail-closed; do not silently remove the wildcard or its
      declaration. Add positive/negative conformance coverage against the full
      schema. Seen2026-11-03 in NovaKind SEPA work; meanwhile NovaKind validates
      V09 with libxml2 `xmllint --nonet` and retains Abla's V03 checks.
      Source: <https://www.iso20022.org/sites/default/files/documents/messages/pain/schemas/pain.001.001.09.xsd>.
      SHA256 `de038b373e47b0077b1832ddd81f4b2f1eb25d35721f62da1e38b7f5a09fda24`.
