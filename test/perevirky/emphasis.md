# Emphasis

This is just a brief demo, the input is just a simple Markdown
paragraph in which one word is emphasized.

``` markdown {#input}
Stuff is *important*!
```

Pandoc parses this into it's internal document format. The default
representation of that format uses Haskell syntax, as pandoc is
written in the Haskell programming language.

``` haskell {#output}
[ Para
    [ Str "Stuff"
    , Space
    , Str "is"
    , Space
    , Emph [ Str "important" ]
    , Str "!"
    ]
]
```

As you can see, the parse result is a single paragraph (`Para`).
The emphasized text is wrapped in an `Emph` element.
