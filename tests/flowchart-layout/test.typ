#import "/src/flowchart/elements.typ": edge, node
#import "/src/flowchart/model.typ": model
#import "/src/flowchart/layout.typ": layout

// Ranking puts each node on a layer (longest path from a source); edges are then
// classified, not split. A one-rank hop is `direct` (these alone shape ordering and
// coordinates), a longer hop is `long` (routed down a corridor), and an edge that
// closes a cycle is `back` (routed up a side channel).
#let g = layout(model((
  node("a", [A]),
  node("b", [B]),
  node("c", [C]),
  node("d", [D]),
  edge("a", "b"),
  edge("b", "c"),
  edge("c", "d"),
  edge("a", "d"), // skips two layers -> long
  edge("d", "b"), // closes the b -> c -> d cycle -> back
)))

#assert.eq(g.ranks, 4)
#assert.eq(g.cells.map(c => c.rank), (0, 1, 2, 3))
#assert.eq(
  g.edges.map(e => e.kind),
  ("direct", "direct", "direct", "long", "back"),
)

// An unanchored node (no direct edges at all) takes its ordering hint from its
// long-edge partners instead of holding its declared slot: `store`, declared
// leftmost, orders onto the side of the right-hand chain it feeds.
#let g2 = layout(model((
  node("store", [S]), // 0 — only a long edge, to the right chain's foot
  node("l0", [L0]), // 1
  node("r0", [R0]), // 2
  node("l1", [L1]),
  node("r1", [R1]),
  node("l2", [L2]),
  node("r2", [R2]),
  edge("l0", "l1"),
  edge("l1", "l2"),
  edge("r0", "r1"),
  edge("r1", "r2"),
  edge("store", "r2"), // rank 0 -> rank 2: long
)))
#assert.eq(g2.edges.last().kind, "long")
#assert(
  g2.cells.at(0).order > g2.cells.at(1).order,
  message: "unanchored store was not ordered toward its long partner's side",
)

// A self-loop stays out of the ranking graph: it is classified `self` and does
// not perturb ranks. Without that, the self-loop poisons the node's in-degree,
// the topological sort stalls, `p` and `q` share rank 0, and the p->q edge is
// mis-ranked "long" (which then crashed the placement pass).
#let g3 = layout(model((
  node("p", [P]),
  node("q", [Q]),
  edge("p", "p"), // self
  edge("p", "q"), // direct, one rank down
)))
#assert.eq(g3.ranks, 2)
#assert.eq(g3.cells.map(c => c.rank), (0, 1))
#assert.eq(g3.edges.map(e => e.kind), ("self", "direct"))
