# The `pivot` Package

<div align="center">Version 0.1.0 · alpha</div>

Cyber Threat Intelligence (CTI) diagrams for [Typst](https://typst.app), built on
[CeTZ](https://github.com/cetz-package/cetz).

<p align="center">
  <img src="https://raw.githubusercontent.com/cybermallard/typst-pivot/main/docs/img/tcp-header.png" alt="A TCP header drawn with pivot" width="540">
</p>

> **Status: alpha** — pre-1.0, so breaking changes can land between minor versions.

## Getting Started

Import the package and compose a diagram from element constructors:

```typ
#import "@preview/pivot:0.1.0": packet, bytes

#figure(
  packet(
    bytes(2)[Source Port],
    bytes(2)[Destination Port],
    bytes(4)[Sequence Number],
  ),
  caption: [TCP header (excerpt)],
)
```

Fields are built by composing `bytes(n)` / `bits(n)`; captions come from Typst's
own `#figure`, not a pivot parameter.

### Installation

pivot is a Typst package — import it from the preview namespace and the compiler
fetches it (and CeTZ) on first build. There's no manual install step:

```typ
#import "@preview/pivot:0.1.0": packet, struct
```

## Diagrams

| Diagram | Status |
|---------|--------|
| Packet / byte-field | done |
| Struct / memory map | in progress |
| Timelines (horizontal, vertical, snaked) | planned |
| Diamond Model | planned |
| Attack tree | planned |
| Bowtie | planned |
| Knowledge graph | planned |
| Sequence | planned |
| Pyramid of Pain | planned |
| Flowchart / state | planned |
| ATT&CK matrix + coverage | planned |

## Documentation

- Comming soon.

## Built on CeTZ

pivot renders with CeTZ, licensed under **LGPL-3.0-or-later**. CeTZ is neither
vendored nor modified; the Typst compiler fetches it independently at build time.

## License

[Apache-2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
