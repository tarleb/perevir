---
perevir:
  filters:
  - test/format-to-meta.lua
---

There's no input:

``` {#input}
```

but the output should include the target format (here: gfm)

``` markdown {#output format=gfm}
---
format: gfm
---

```
