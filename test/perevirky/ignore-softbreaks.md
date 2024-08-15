---
perevir:
  ignore-softbreaks: true
---

Here's an input text with very short lines:

``` markdown {#input}
Every
word
is
on
a
separate
line.
```

Normally, perevir wouldn't match this to the same sentence on one line.

``` markdown {#output}
Every word is on a separate line.
```

However, since the `ignore-softbreaks` option is enabled for this
test, all softbreaks are converted to spaces, and thus the test
passes.
