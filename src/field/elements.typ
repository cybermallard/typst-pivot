// Field element constructors — the byte-region cluster's shared vocabulary
// (packet, struct, hexdump all build from these). Each returns a plain descriptor
// dict that `model` consumes; the author supplies widths and labels, never bit
// positions. Pure.
// `at:` anchors a field to an absolute BIT offset (a `unit:` for byte-oriented
// offsets is planned for the `struct` sibling; today `at:` is in bits). `fill:`
// highlights a field. `gap` is a dashed "unparsed" span; `reserved` is a plain
// empty field (reserved bits). Labels are positional trailing content.

#let bytes(n, label, at: none, fill: none) = (
  kind: "field",
  width: n * 8,
  label: label,
  anchor: at,
  fill: fill,
)

#let bits(n, label, at: none, fill: none) = (
  kind: "field",
  width: n,
  label: label,
  anchor: at,
  fill: fill,
)

#let gap(n, ..rest) = (
  kind: "gap",
  width: n,
  label: rest.pos().at(0, default: none),
  anchor: none,
  fill: none,
)

#let reserved(n, ..rest) = (
  kind: "field",
  width: n,
  label: rest.pos().at(0, default: none),
  anchor: none,
  fill: none,
)
