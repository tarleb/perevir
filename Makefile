.PHONY: test \
		test-acceptance test-filter test-sections \
		test-custom-reader

test: \
		test-acceptance \
		test-filter \
		test-sections \
		test-custom-reader
	@pandoc-lua test/md-checker.lua test/markdown/emphasis.md
	@if pandoc-lua test/md-checker.lua test/markdown/failure.md 2>/dev/null; then \
	    exit 1; \
	fi

test-acceptance:
	@test/check-acceptance.sh test/markdown/failure.md test/markdown/emphasis.md

test-filter:
	@pandoc-lua perevir.lua test/markdown/check-filter.md

test-sections:
	@pandoc-lua perevir.lua test/markdown/sections.md

test-custom-reader:
	@pandoc-lua test/plain-checker.lua test/markdown/plain.md
