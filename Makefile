PROJECT_DIR := $(abspath .)
ABLAC_DIR ?= $(abspath ../ablac)
COMPILER ?= $(ABLAC_DIR)/build/ablac
BUILD_DIR ?= $(PROJECT_DIR)/build
SUITE_DIR ?= $(PROJECT_DIR)/.conformance
CORPUS_DIR ?= $(BUILD_DIR)/corpus
FUZZ_ITERATIONS ?= 200000
FUZZ_SEED ?= 1

.PHONY: test unit conformance written fuzz security differential wildcard-oracle big all clean

all: unit conformance written fuzz

test: unit

unit:
	$(COMPILER) test tests/writer_test.ab tests/reader_test.ab tests/roundtrip_test.ab tests/stream_test.ab tests/xsd_test.ab tests/xsd_regex_test.ab tests/xsd_wildcard_test.ab

# Local, offline comparison with libxml2; needs xmllint on PATH.
wildcard-oracle:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/xsd-check.ab -o $(BUILD_DIR)/xsd-check
	bash tools/xsd-wildcard-oracle.sh $(BUILD_DIR)/xsd-check $(BUILD_DIR)/wildcard-oracle

conformance:
	mkdir -p $(BUILD_DIR)
	bash tools/fetch-conformance.sh $(SUITE_DIR)
	$(COMPILER) build tools/conformance.ab -o $(BUILD_DIR)/conformance
	$(BUILD_DIR)/conformance $(SUITE_DIR)/xmlconf tools/conformance-expected.txt
	$(COMPILER) build tools/stream-compare.ab -o $(BUILD_DIR)/stream-compare
	find $(SUITE_DIR)/xmlconf -type f -size -1024k > $(BUILD_DIR)/stream-files.txt
	$(BUILD_DIR)/stream-compare $(BUILD_DIR)/stream-files.txt

# Written documents against xmllint (libxml2); needs it on the PATH.
written:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/write-corpus.ab -o $(BUILD_DIR)/write-corpus
	rm -rf $(CORPUS_DIR)
	$(BUILD_DIR)/write-corpus $(CORPUS_DIR) 2000
	cd $(CORPUS_DIR) && find . -name '*.xml' -print0 | xargs -0 -n 200 xmllint --noout --nonet
	$(COMPILER) build tools/check-written.ab -o $(BUILD_DIR)/check-written
	bash tools/check-written.sh $(BUILD_DIR)/check-written $(CORPUS_DIR)

fuzz:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/fuzz.ab -o $(BUILD_DIR)/fuzz
	bash tools/fetch-conformance.sh $(SUITE_DIR)
	find $(SUITE_DIR)/xmlconf -name '*.xml' -size -16k > $(BUILD_DIR)/fuzz-seeds.txt
	$(BUILD_DIR)/fuzz $(FUZZ_ITERATIONS) $(FUZZ_SEED) $(BUILD_DIR)/fuzz-seeds.txt

# Security checks that are not fuzzing (tools/security.ab): every limit at its boundary, the entity limits, the XSD regex's cost, the writer's escaping through the parser,
# the decoders against Unicode's tables, and deep trees; and (tools/xsd-security.ab) what an untrusted schema or instance can make the XSD validator do. Takes under a minute.
security:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/security.ab -o $(BUILD_DIR)/security
	$(BUILD_DIR)/security limits
	$(BUILD_DIR)/security regex
	$(BUILD_DIR)/security cp1252
	$(BUILD_DIR)/security utf16
	$(BUILD_DIR)/security utf8 200000 1
	$(BUILD_DIR)/security writer 20000 1
	$(BUILD_DIR)/security depth 20000 text
	$(BUILD_DIR)/security depth 1000000 write
	$(COMPILER) build tools/xsd-security.ab -o $(BUILD_DIR)/xsd-security
	for kind in simple-base complex-base group attribute-group substitution element-ref self-type; do $(BUILD_DIR)/xsd-security cycle $$kind || exit 1; done
	$(BUILD_DIR)/xsd-security include
	$(BUILD_DIR)/xsd-security particles
	$(BUILD_DIR)/xsd-security chain 10000
	$(BUILD_DIR)/xsd-security nest 1000
	$(BUILD_DIR)/xsd-security xpath parens 100000
	$(BUILD_DIR)/xsd-security xpath not 100000
	$(BUILD_DIR)/xsd-security xpath if 100000
	$(BUILD_DIR)/xsd-security xpath or 100000
	$(BUILD_DIR)/xsd-security xpath and 100000
	$(BUILD_DIR)/xsd-security assert miss 30000
	$(BUILD_DIR)/xsd-security assert missint 5000
	$(BUILD_DIR)/xsd-security identity 100000

# Prints where this parser and xmllint disagree on fuzz inputs. Not pass or fail.
differential:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/fuzz.ab -o $(BUILD_DIR)/fuzz
	bash tools/fetch-conformance.sh $(SUITE_DIR)
	find $(SUITE_DIR)/xmlconf -name '*.xml' -size -16k > $(BUILD_DIR)/fuzz-seeds.txt
	rm -rf $(BUILD_DIR)/fuzz-dump
	$(BUILD_DIR)/fuzz 100000 $(FUZZ_SEED) $(BUILD_DIR)/fuzz-seeds.txt $(BUILD_DIR)/fuzz-dump
	bash tools/compare-xmllint.sh $(BUILD_DIR)/fuzz-dump

# At least 3 GiB through files, with peak memory. Local only; needs xmllint and GNU time.
BIG_DIR ?= /tmp
big:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/big-file.ab -o $(BUILD_DIR)/big-file
	tools/big-file.sh $(BUILD_DIR)/big-file $(BIG_DIR)

clean:
	@if [ -d "$(BUILD_DIR)" ]; then gio trash "$(BUILD_DIR)"; fi
