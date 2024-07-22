# Input and Expected Output in Sections

This test checks whether we can use normal Markdown sections as expected
input and output. We're using different emphasis syntax to demonstrate
the use of Pandoc elements to make the comparison.

## Input

*Emphasis* and **strong emphasis**.

## Expected

_Emphasis_ and __strong emphasis__.

## Explanation

The markup for the input uses `*` as emphasis marker, while
emphasized text in the "Expected" section are marked with `_`. So
`*Emphasis*` and `_Emphasis_`, respectively. They have the same
semantics in Markdown, so pandoc's internal representation is the
same for both paragraphs.
