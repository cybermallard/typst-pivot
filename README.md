# pivot

<p align="center">
  <a href="https://github.com/cybermallard/typst-pivot/actions/workflows/ci.yml"><img src="https://github.com/cybermallard/typst-pivot/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/version-0.1.0-orange.svg" alt="Version 0.1.0 (alpha)">
  <img src="https://img.shields.io/badge/Typst-0.14%2B-239dad.svg" alt="Typst 0.14+">
</p>

Cyber Threat Intelligence (CTI) diagrams for [Typst](https://typst.app). The defaults produce clean and readable diagrams with colour-blind friendly colours.

<table align="center">
  <tr>
    <td align="center" valign="top">
      <img src="https://raw.githubusercontent.com/cybermallard/typst-pivot/main/docs/img/tcp-header.png" height="260" alt="packet: a TCP header, narrow flags as leader callouts"><br>
      <sub><b>packet</b> · protocol header</sub>
    </td>
    <td align="center" valign="top">
      <img src="https://raw.githubusercontent.com/cybermallard/typst-pivot/main/docs/img/struct-malware-c2.png" height="260" alt="struct: a malware C2 config as a memory map"><br>
      <sub><b>struct</b> · memory map</sub>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center" valign="top">
      <img src="https://raw.githubusercontent.com/cybermallard/typst-pivot/main/docs/img/hexdump-gh0st.png" width="100%" alt="hexdump: a Gh0st RAT C2 header annotated"><br>
      <sub><b>hexdump</b> · annotated bytes</sub>
    </td>
  </tr>
</table>

<p align="center"><sub><i>a TCP header (narrow flags fan out as leader callouts), a malware C2 config as a memory map, and a Gh0st RAT check-in annotated in a hexdump.</i></sub></p>

## Installation

pivot is a Typst package — import it from the preview namespace and the compiler
fetches it (and CeTZ) on first build. There's no manual install step:

```typ
#import "@preview/pivot:0.1.0": packet, struct, hexdump
```

## Using pivot

One vocabulary drives all three views — `bytes(n)`, `bits(n)`, `gap(n)`,
`reserved(n)`, with `at:` (offset) and `fill:` (highlight). You write widths and
labels; pivot derives every offset, row, and ruler number. The gallery diagrams
above are built from calls like these:

A **`packet`** — the TCP header, with the sequence and acknowledgment numbers
highlighted (the narrow flag bits become leader callouts automatically):

```typ
#import "@preview/pivot:0.1.0": packet, struct, hexdump, bytes, bits, gap, palette

#packet(
  bytes(2)[Source Port], bytes(2)[Destination Port],
  bytes(4, fill: palette.blue)[Sequence Number],
  bytes(4, fill: palette.blue)[Acknowledgment Number],
  bits(4)[Data Offset], bits(6)[Reserved],
  bits(1)[URG], bits(1)[ACK], bits(1)[PSH], bits(1)[RST], bits(1)[SYN], bits(1)[FIN],
  bytes(2)[Window],
  bytes(2)[Checksum], bytes(2)[Urgent Pointer],
)
```

The same vocabulary as a **`struct`** — a malware C2 beacon header as a memory map:

```typ
#struct(
  bytes(4)[Magic],
  bytes(1)[Version], bytes(1)[Command], bytes(2)[Bot ID],
  bytes(4, fill: palette.orange)[Campaign Key],
  gap(16)[unparsed], bytes(2)[Payload Len],
)
```

And **`hexdump`** — a Gh0st RAT C2 check-in, fields annotated in the captured bytes:

```typ
#hexdump(
  data: read("ghost-checkin.bin", encoding: none),
  bytes(5, at: 0x00)[Magic: "Gh0st"],
  bytes(4, at: 0x05)[Total size (LE)],
  bytes(4, at: 0x09)[Uncompressed size (LE)],
  bytes(57, at: 0x0d)[zlib payload (0x78 9C)],
)
```


## Diagrams

**Available Diagrams**

| | |
|---|---|
| **`packet`** | Flat protocol-header view — fields wrap into rows under a bit ruler; narrow labels become leader callouts. |
| **`struct`** | Vertical memory map — box height tracks byte size, hex offsets down the side, sub-byte fields expand in place. |
| **`hexdump`** | Real bytes with an ASCII gutter, fields highlighted in place and keyed in a colour legend. |

All three share one field vocabulary (`bytes` / `bits` / `gap` / `reserved`) over
the same model, so views of the same bytes can't disagree.

**Diagram Roadmap**

_Alphabetical order, i.e., not the order in which they will be released._

| | |
|---|---|
| ATT&CK matrix | Technique coverage as a grid. |
| Attack tree | A hierarchical representation of paths an adversary could take to achieve a goal. |
| Bowtie | A event at the center, threats on the left, consequences on the right, annotated with preventive and mitigating barriers. |
| Diamond Model | The four vertices: adversary, capability, infrastructure, victim. |
| Flowchart | A step-by-step view of a process and its decision points.|
| Knowledge graph | Typed entities as nodes joined by labelled edges. |
| Pyramid of Pain | Indicator types ranked by adversary cost. |
| Sequence | A time-ordered view of interactions between parties. |
| Timelines | Events on an ordered axis — horizontal, vertical, or snaked. |

## Documentation

Full docs are in progress. For now, [`examples/`](examples) has a runnable example
for every diagram.

### Adding a caption to a diagram

Captions come from Typst's own `figure` function. The default caption gap is a little tight, 
a slightly wider `#set figure(gap: 1em)` reads better:

```typ
#set figure(gap: 1em) // a little more room than the 0.65em default

#figure(
  packet(
    bytes(2)[Source Port], bytes(2)[Destination Port],
    bytes(4)[Sequence Number],
  ),
  caption: [TCP header (excerpt)],
)
```

## Built on CeTZ

pivot renders with CeTZ, licensed under **LGPL-3.0-or-later**. CeTZ is neither
vendored nor modified; the Typst compiler fetches it independently at build time.

## License

[Apache-2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
