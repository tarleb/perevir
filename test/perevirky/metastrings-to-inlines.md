---
perevir:
  metastrings-to-inlines: true
---

``` org {#input}
#+TITLE: Привіт!
#+LANGUAGE: uk
```

The `test` metavalue would normally be of type *MetaString*, but
since the `metastrings-to-inlines` option is set, it gets
converted to a *MetaInlines* value. Thanks to that we can use
Markdown to provide the expected output, as the Markdown reader
would never produce *MetaString* values.

``` markdown {#expected}
---
lang: uk
title: Привіт!
---
```
