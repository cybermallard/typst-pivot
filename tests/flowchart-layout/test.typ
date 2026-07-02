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
