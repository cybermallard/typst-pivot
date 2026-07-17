// Flowchart element constructors. A flowchart is a set of `node`s joined by
// directed `edge`s; both are passed together in one variadic `flowchart(..)` call
// and the model sorts them out. A node has an id (referenced by edges), a label
// (trailing content), a shape, and an opt-in fill. An edge names a source and a
// target node id and an optional label — a branch condition like "yes" / "no".
// Pure; no cetz.
//
//   node("q", [Known-bad hash?], shape: "diamond")
//   edge("q", "block", label: [yes])

#let node(id, label, shape: "rectangle", fill: none) = (
  kind: "node",
  id: id,
  label: label,
  shape: shape,
  fill: fill,
)

// `label-offset` is the escape hatch for a stubborn label: a `(x, y)` pair of
// lengths that shifts *this* label from wherever the layout placed it — `+y`
// up, `+x` right, as seen on the finished page (the same in either
// orientation). The move is honoured exactly (the automatic dodging of nodes,
// other labels and lines is for the unattended case; here the author has
// decided), and later labels treat the moved position as occupied, so nudging
// one never quietly buries another.
//
//   edge("orch", "llm", label: [Queries LLM], label-offset: (0pt, 5pt))
#let edge(from, to, label: none, label-offset: none) = (
  kind: "edge",
  from: from,
  to: to,
  label: label,
  label-offset: label-offset,
)
