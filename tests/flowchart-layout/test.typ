#import "/src/flowchart/elements.typ": edge, group, node
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

// Rank slack: a source holds nothing up, so it sinks to one layer above its
// nearest consumer instead of being pinned to the top with an edge running
// the whole height of the chart. `store`, whose only consumer sits at rank
// 2, comes to rest at rank 1 — and its edge, now a one-rank hop, is direct.
#let g2 = layout(model((
  node("store", [S]), // 0 — feeds only the right chain's foot
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
  edge("store", "r2"), // consumer two layers down: store sinks beside it
)))
#assert.eq(g2.cells.at(0).rank, 1)
#assert.eq(g2.edges.last().kind, "direct")

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

// Groups: the model resolves nesting (paths, depths, transitive members) and
// the ordering keeps a group's members contiguous in every rank, even when an
// outsider's neighbours would pull it between them. A(2) and B(4) share a
// group; their rank-1 barycenters interleave with loose L(3), yet they must
// end up adjacent.
#let g4 = layout(model((
  node("p1", [P1]),
  node("p2", [P2]),
  node("p3", [P3]),
  node("p4", [P4]),
  node("s", [S]),
  node("A", [A]),
  node("L", [L]),
  node("B", [B]),
  node("R", [R], outline: green),
  edge("s", "p1"),
  edge("s", "p2"),
  edge("s", "p3"),
  edge("s", "p4"),
  edge("p1", "A"),
  edge("p2", "L"),
  edge("p3", "B"),
  edge("p4", "R"),
  group("inner", [Inner], "A", "B", border-color: red),
  group("outer", [Outer], "inner", "L"),
)))
#let cell = id => g4.cells.find(c => c.id == id)
#assert.eq(cell("A").gpath, ("outer", "inner"))
#assert.eq(cell("L").gpath, ("outer",))
#assert.eq(cell("R").gpath, ())
#assert.eq(g4.groups.find(g => g.id == "inner").depth, 1)
#assert.eq(g4.groups.find(g => g.id == "outer").depth, 0)
// Style carries through the model unchanged; an unset border-color is `none`.
#assert.eq(g4.groups.find(g => g.id == "inner").border-color, red)
#assert.eq(g4.groups.find(g => g.id == "outer").border-color, none)
// A node's `outline` colour carries through model + layout; unset is `none`.
#assert.eq(cell("R").outline, green)
#assert.eq(cell("A").outline, none)
#assert.eq(
  g4.groups.find(g => g.id == "outer").nodes.len(),
  3, // A, B and L — transitive through `inner`
)
#assert.eq(
  calc.abs(cell("A").order - cell("B").order),
  1,
  message: "grouped nodes A and B were not contiguous in their rank",
)
