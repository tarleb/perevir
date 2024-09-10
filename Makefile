.PHONY: test \
		test-%
		test-acceptance \
		test-custom-reader \
		test-custom-writer \
		test-diroptions

test: \
		test-acceptance \
		test-custom-reader \
		test-custom-writer \
		test-diroptions \
		test-check-filter \
		test-citeproc \
		test-compare-strings \
		test-disabled \
		test-emphasis \
		test-expected-in-div \
		test-format-in-filter \
		test-ignore-softbreaks \
		test-math \
		test-metastrings-to-inlines \
		test-output-in-html \
		test-sections
	@pandoc-lua test/md-checker.lua test/perevirky/emphasis.md
	@if pandoc-lua test/md-checker.lua test/perevirky/failure.md 2>/dev/null; then \
	    exit 1; \
	fi

test-acceptance:
	@test/accept/check-acceptance.sh test/accept/failure.md test/accept/accepted.md

test-diroptions:
	@pandoc-lua perevir.lua test/dir-options/smallcaps.md
	@pandoc-lua perevir.lua test/dir-options

test-custom-reader:
	@pandoc-lua test/plain-checker.lua test/perevirky/plain.md

test-custom-writer:
	@pandoc-lua test/custom-writer/custom-tester.lua \
	    test/custom-writer/custom-writer-perevirka.md

test-%:
	@pandoc-lua perevir.lua test/perevirky/$*.md
