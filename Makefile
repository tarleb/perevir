.PHONY: test test-acceptance test-filter
test: test-acceptance test-filter
	@pandoc-lua test/md-checker.lua test/markdown/emphasis.md
	@if pandoc-lua test/md-checker.lua test/markdown/failure.md 2>/dev/null; then \
	    exit 1; \
	fi

test-acceptance:
	@test/check-acceptance.sh test/markdown/failure.md test/markdown/emphasis.md

test-filter:
	@pandoc-lua perevir.lua test/markdown/check-filter.md
