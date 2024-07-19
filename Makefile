.PHONY: test test-acceptance
test: test-acceptance
	@pandoc-lua test/md-checker.lua test/markdown/emphasis.md
	@if pandoc-lua test/md-checker.lua test/markdown/failure.md 2>/dev/null; then \
	    exit 1; \
	fi

test-acceptance:
	@test/check-acceptance.sh test/markdown/failure.md test/markdown/emphasis.md
