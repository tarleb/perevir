---
perevir:
  compare: strings
---

This Markdown contains raw HTML:

``` markdown {#input}
Not interesting.`<aside>duh</aside>`{=html}
```

The expected result is given as an HTML block. However, the HTML
snippet would not be read back as raw HTML, so the test would
normally fail. But, as the `compare` option is set to `string`,
perevir compares the string output, not the bare documents.

``` html {#expected}
<p>Not interesting.<aside>duh</aside></p>
```
