#!/usr/bin/env bash
set -euo pipefail
checker=$1
folder=$2
mkdir -p "$folder"
checked=0
printf '%s\n' 'de038b373e47b0077b1832ddd81f4b2f1eb25d35721f62da1e38b7f5a09fda24  tests/fixtures/pain.001.001.09.xsd' | sha256sum -c -
compare() {
  local schema=$1 document=$2 expected=$3 actual oracle
  if "$checker" "$schema" "$document" > "$folder/abla.log" 2>&1; then actual=0; else actual=$?; fi
  if xmllint --nonet --noout --schema "$schema" "$document" > "$folder/libxml.log" 2>&1; then oracle=0; else oracle=$?; fi
  local oracle_expected=0
  if [ "$expected" -eq 1 ]; then oracle_expected=3; fi
  if [ "$actual" -ne "$expected" ] || [ "$oracle" -ne "$oracle_expected" ]; then
    printf 'FAIL expected=%s Abla=%s libxml=%s %s\n' "$expected" "$actual" "$oracle" "$document"
    cat "$folder/abla.log" "$folder/libxml.log"
    exit 1
  fi
  checked=$((checked+1))
}
for mode in strict lax skip; do
  cat > "$folder/$mode.xsd" <<EOF
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t" elementFormDefault="qualified"><xs:element name="known" type="xs:int"/><xs:element name="r"><xs:complexType><xs:sequence><xs:any processContents="$mode"/></xs:sequence></xs:complexType></xs:element></xs:schema>
EOF
  printf '%s' '<r xmlns="urn:t"><known>7</known></r>' > "$folder/known.xml"
  printf '%s' '<r xmlns="urn:t"><known>bad</known></r>' > "$folder/value.xml"
  printf '%s' '<r xmlns="urn:t"><unknown><nested/></unknown></r>' > "$folder/unknown.xml"
  printf '%s' '<r xmlns="urn:t"><unknown><known>bad</known></unknown></r>' > "$folder/nested.xml"
  compare "$folder/$mode.xsd" "$folder/known.xml" 0
  if [ "$mode" = skip ]; then bad=0; else bad=1; fi
  compare "$folder/$mode.xsd" "$folder/value.xml" "$bad"
  if [ "$mode" = strict ]; then unknown=1; else unknown=0; fi
  compare "$folder/$mode.xsd" "$folder/unknown.xml" "$unknown"
  compare "$folder/$mode.xsd" "$folder/nested.xml" "$bad"
done
cat > "$folder/other.xsd" <<'EOF'
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t" elementFormDefault="qualified"><xs:element name="r"><xs:complexType><xs:sequence><xs:any namespace="##other" processContents="lax"/></xs:sequence></xs:complexType></xs:element></xs:schema>
EOF
printf '%s' '<r xmlns="urn:t"><x xmlns="urn:foreign"/></r>' > "$folder/foreign.xml"
printf '%s' '<r xmlns="urn:t"><x/></r>' > "$folder/target.xml"
printf '%s' '<r xmlns="urn:t"><x xmlns=""/></r>' > "$folder/local.xml"
compare "$folder/other.xsd" "$folder/foreign.xml" 0
compare "$folder/other.xsd" "$folder/target.xml" 1
compare "$folder/other.xsd" "$folder/local.xml" 1
compare tests/fixtures/pain.001.001.09.xsd tests/fixtures/pain09.xml 0
sed 's#</CstmrCdtTrfInitn>#<SplmtryData><Envlp><proof xmlns="urn:example:proof"><value>synthetic</value></proof></Envlp></SplmtryData></CstmrCdtTrfInitn>#' tests/fixtures/pain09.xml > "$folder/supplement.xml"
compare tests/fixtures/pain.001.001.09.xsd "$folder/supplement.xml" 0
sed 's#<InstdAmt Ccy="EUR">12.34#<InstdAmt Ccy="EUR">bad#' tests/fixtures/pain09.xml > "$folder/bad-amount.xml"
compare tests/fixtures/pain.001.001.09.xsd "$folder/bad-amount.xml" 1
sed 's#</CstmrCdtTrfInitn>#<SplmtryData><Envlp/></SplmtryData></CstmrCdtTrfInitn>#' tests/fixtures/pain09.xml > "$folder/empty-envelope.xml"
compare tests/fixtures/pain.001.001.09.xsd "$folder/empty-envelope.xml" 1
printf '%s independent Abla/libxml2 verdicts passed\n' "$checked"
