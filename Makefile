.PHONY: test
test:
	@pandoc-lua test/md-checker.lua test/markdown/emphasis.md
	@if pandoc-lua test/md-checker.lua test/markdown/failure.md 2>/dev/null; then \
	    exit 1; \
	fi
