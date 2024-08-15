Checks if the filter specified in the options file is applied.

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
