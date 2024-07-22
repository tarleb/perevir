---
perevir:
  filters:
  - test/smallcaps.lua
---

This test checks filter handling. The filters listed under the
`perevir.filters` metadata field must all be run on the given
input.

``` markdown {#input}
Let's turn _*this*_ into [this]{.smallcaps}.
```

Here we're using a filter that converts doubly-emphasized text
into smallcaps. We're using pandoc's internal AST (abstract syntax
tree) for the expected output, as that's most suitable to
capture this information.

``` haskell {#expected}
[ Para
    [ Str "Let\8217s"
    , Space
    , Str "turn"
    , Space
    , SmallCaps [ Str "this" ]
    , Space
    , Str "into"
    , Space
    , SmallCaps [ Str "this" ]
    , Str "."
    ]
]
```
