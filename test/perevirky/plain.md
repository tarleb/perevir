# Plain reader

This test expects a different reader to be used to parse the
input. For that we're using customized version of `perevir`,
available in the file `test/plain-checker.lua`. In can be used
just like the default `perevir` program.

``` {#input}
Stuff is *important*!
```

As can be seen below, Markdown highlighting is no longer
recognized.

``` haskell {#output}
[ Para
    [ Str "Stuff"
    , Space
    , Str "is"
    , Space
    , Str "*important*!"
    ]
]
```
