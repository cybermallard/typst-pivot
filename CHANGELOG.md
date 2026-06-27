# Changelog

All notable changes to pivot are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project uses
[Semantic Versioning](https://semver.org/). Pre-1.0, breaking changes to the
public API or data contracts may land in a minor release and are announced here
with a migration note.

## [Unreleased]

### Added
- Project foundation: package manifest pinned to `@preview/cetz:0.5.2`
  (Typst ≥ 0.14.0; toolchain runs Typst 0.14.2 via tytanic), Apache-2.0 licensing,
  CI, and the version-pin guard.
- Packet diagram: `packet` with `bytes`/`bits`/`gap`/`reserved` element
  constructors, `at:`/`fill:` modifiers, auto-flow wrapping, measure-based
  narrow-field leader callouts (`callout: "left" | "gap"`; a crowded row whose
  leaders would cross auto-switches to a single outside-the-frame column), a
  deduplicating bit ruler (`ruler: "dedup"` default, `"full"` numbers every edge),
  and a theme system
  (the bit ruler is pinned to an embedded monospace, so it stays mono and aligned
  under any document label font).
- Struct diagram: `struct`, the byte-region cluster's vertical memory-map view —
  fields stacked top-down with box height proportional to byte size (oversized
  fields capped with a torn break-mark edge), hex byte offsets centred on their
  boundaries, sizes down the right, reusing the shared
  `bytes`/`bits`/`gap`/`reserved` vocabulary and `fill:`/gap conventions. Shares
  the pure field model (`src/field/`) with packet; renderer is its own.
- Struct bit-field expansion: a byte carved into sub-byte fields renders as one
  proportional row subdivided into floated, numbered bit-cells (straddle-correct
  for fields crossing a byte). Names that don't fit a cell become crossing-free
  leader callouts placed outside the frame. Layer/cell gaps match packet's
  `row-gap`/`col-gap`.
- Rendered example diagrams under `docs/img/`.
