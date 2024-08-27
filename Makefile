.PHONY: test \
		test-%
		test-acceptance \
		test-diroptions \
		test-disabled \
		test-filter \
		test-ignore-softbreaks \
		test-sections \
		test-custom-reader

test: \
		test-acceptance \
		test-diroptions \
		test-disabled \
		test-filter \
		test-ignore-softbreaks \
		test-sections \
		test-custom-reader
	@pandoc-lua test/md-checker.lua test/perevirky/emphasis.md
	@if pandoc-lua test/md-checker.lua test/perevirky/failure.md 2>/dev/null; then \
	    exit 1; \
	fi

test-acceptance:
	@test/accept/check-acceptance.sh test/accept/failure.md test/accept/accepted.md

test-filter:
	@pandoc-lua perevir.lua test/perevirky/check-filter.md

test-diroptions:
	@pandoc-lua perevir.lua test/dir-options/smallcaps.md
	@pandoc-lua perevir.lua test/dir-options

test-custom-reader:
	@pandoc-lua test/plain-checker.lua test/perevirky/plain.md

test-%:
	@pandoc-lua perevir.lua test/perevirky/$*.md
