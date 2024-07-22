---
perevir:
  filters:
  - test/smallcaps.lua
---

``` {#input}
Let's turn _*this*_ into [this]{.smallcaps}.
```

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
