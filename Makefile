PROJECT_DIR := $(abspath .)
ABLAC_DIR ?= $(abspath ../ablac)
COMPILER ?= $(ABLAC_DIR)/build/ablac
BUILD_DIR ?= $(PROJECT_DIR)/build
SUITE_DIR ?= $(PROJECT_DIR)/.conformance
CORPUS_DIR ?= $(BUILD_DIR)/corpus
FUZZ_ITERATIONS ?= 200000
FUZZ_SEED ?= 1

.PHONY: test unit conformance written fuzz differential all clean

all: unit conformance written fuzz

test: unit

unit:
	$(COMPILER) test tests/writer_test.ab tests/reader_test.ab tests/roundtrip_test.ab

conformance:
	mkdir -p $(BUILD_DIR)
	bash tools/fetch-conformance.sh $(SUITE_DIR)
	$(COMPILER) build tools/conformance.ab -o $(BUILD_DIR)/conformance
	$(BUILD_DIR)/conformance $(SUITE_DIR)/xmlconf tools/conformance-expected.txt

# Written documents against xmllint and expat; needs both on the PATH.
written:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/write-corpus.ab -o $(BUILD_DIR)/write-corpus
	rm -rf $(CORPUS_DIR)
	$(BUILD_DIR)/write-corpus $(CORPUS_DIR) 2000
	cd $(CORPUS_DIR) && find . -name '*.xml' -print0 | xargs -0 -n 200 xmllint --noout --nonet
	python3 -I tools/check-written.py $(CORPUS_DIR)

fuzz:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/fuzz.ab -o $(BUILD_DIR)/fuzz
	bash tools/fetch-conformance.sh $(SUITE_DIR)
	find $(SUITE_DIR)/xmlconf -name '*.xml' -size -16k > $(BUILD_DIR)/fuzz-seeds.txt
	$(BUILD_DIR)/fuzz $(FUZZ_ITERATIONS) $(FUZZ_SEED) $(BUILD_DIR)/fuzz-seeds.txt

# Prints where this parser and xmllint disagree on fuzz inputs. Not pass or fail.
differential:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tools/fuzz.ab -o $(BUILD_DIR)/fuzz
	bash tools/fetch-conformance.sh $(SUITE_DIR)
	find $(SUITE_DIR)/xmlconf -name '*.xml' -size -16k > $(BUILD_DIR)/fuzz-seeds.txt
	rm -rf $(BUILD_DIR)/fuzz-dump
	$(BUILD_DIR)/fuzz 100000 $(FUZZ_SEED) $(BUILD_DIR)/fuzz-seeds.txt $(BUILD_DIR)/fuzz-dump
	python3 -I tools/compare-xmllint.py $(BUILD_DIR)/fuzz-dump

clean:
	@if [ -d "$(BUILD_DIR)" ]; then gio trash "$(BUILD_DIR)"; fi
