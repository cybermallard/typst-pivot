---
name: Bug report
about: A diagram renders incorrectly, errors, or its output disagrees with the input
title: ""
labels: bug
---

**What's wrong**
What happened, vs. what you expected.

**Minimal reproduction**
The smallest call that shows it:

```typ
#import "@preview/pivot:0.1.0": packet, struct, bytes, bits, gap
#packet(
  // ...
)
```

**Output**
The rendered result (screenshot or PDF), and what it should look like instead.

**Versions**
- pivot:
- Typst:
- CeTZ:

**Note**
pivot enforces *veracity* (the numbers match the geometry), **not** standard-conformance — drawing a malformed or unusual structure faithfully is intended. A bug is when the geometry disagrees with the input, it errors, or it refuses a legitimate-but-unusual structure.
