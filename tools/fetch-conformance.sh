#!/usr/bin/env bash
# Downloads the W3C XML conformance suite into .conformance/, checking its hash.
# It stays out of git: its files carry many owners' copyrights, some with all
# rights reserved.
set -euo pipefail
url=https://www.w3.org/XML/Test/xmlts20130923.tar.gz
hash=9b61db9f5dbffa545f4b8d78422167083a8568c59bd1129f94138f936cf6fc1f
directory=${1:-.conformance}
if [ -f "$directory/xmlconf/xmlconf.xml" ]; then exit 0; fi
mkdir -p "$directory"
curl -fsSL --retry 3 -o "$directory/suite.tar.gz" "$url"
echo "$hash  $directory/suite.tar.gz" | sha256sum -c --quiet
tar -xzf "$directory/suite.tar.gz" -C "$directory"
