#import "/src/flowchart/elements.typ": edge, node
#import "/src/flowchart/model.typ": model
#import "/src/flowchart/layout.typ": layout
#import "/src/flowchart/place.typ": place

// Placement is pure math over measured sizes, so it is asserted numerically:
// fabricated sizes stand in for label measurement and make every check
// deterministic. The invariant under test is the one that broke (a cascaded
// widening left a merge narrower than its inputs' final positions): after
// placement, every node spans each of its seated inputs with `pad-x` to spare.

#let tok = (node-gap: 0.7, rank-gap: 1.3, pad-x: 0.45, back-margin: 0.6)

// Every cell the same size — topology, not labels, drives these tests.
#let sizes(g, w: 3.0, h: 1.0) = g.cells.map(c => (..c, w: w, h: h, th: h))

#let placed(g) = place(
  sizes(g),
  g.edges,
  g.ranks,
  node-gap: tok.node-gap,
  rank-gap: tok.rank-gap,
  pad-x: tok.pad-x,
  back-margin: tok.back-margin,
)

// The seat invariant: a node with two or more direct inputs spans each input's
// column, and a node with long inputs reaches each entry column — both inset by
// pad-x (within the widen loop's own settle tolerance).
#let check-seats(g, p) = {
  let slack = 0.01
  let din = (:)
  for e in g.edges {
    if e.kind == "direct" {
      din.insert(str(e.to), din.at(str(e.to), default: ()) + (e.from,))
    }
  }
  for (k, parents) in din {
    if parents.len() >= 2 {
      for s in parents {
        let reach = calc.abs(p.x.at(str(s)) - p.x.at(k))
        assert(
          p.w.at(k) / 2 + slack >= reach + tok.pad-x,
          message: "merge node " + k + " does not span its input at " + str(s),
        )
      }
    }
  }
  for (ei, e) in g.edges.enumerate() {
    if e.kind == "long" {
      let r = p.route.at(str(ei))
      let reach = calc.abs(r.entry - p.x.at(str(e.to)))
      assert(
        p.w.at(str(e.to)) / 2 + slack >= reach + tok.pad-x,
        message: "long entry into node " + str(e.to) + " lands outside it",
      )
    }
  }
}

// --- the MAR triage shape: a two-level cascade -------------------------------
// `clear` widens (a direct input plus a long input from `task`) and moves during
// relaxation; `out` merges `ir` + `clear` on top of that. Three fixed rounds left
// `out`'s width stale here — the regression this file pins down.
#let mar = layout(model((
  node("in", [I]),
  node("task", [T], shape: "diamond"),
  node("mem", [M], shape: "parallelogram"),
  node("c2", [C], shape: "diamond"),
  node("ir", [R]),
  node("clear", [K]),
  node("out", [O], shape: "rounded"),
  edge("in", "task"),
  edge("task", "mem"),
  edge("task", "clear"), // skips two ranks -> long; widens `clear` (level 1)
  edge("mem", "c2"),
  edge("c2", "ir"),
  edge("c2", "clear"),
  edge("ir", "out"),
  edge("clear", "out"), // merge on a moved parent (level 2)
)))
#let mar-p = placed(mar)
#assert(mar-p.settled, message: "mar cascade: widen loop did not settle")
#check-seats(mar, mar-p)

// --- one level deeper: three chained widenings -------------------------------
// `b` widens for a long input; `c` widens for a long entry whose corridor shifts
// with `b`; `m` merges `c` with `d`. Each round propagates one level, so this
// needs strictly more rounds than the mar shape.
#let deep = layout(model((
  node("s", [S]),
  node("a", [A]),
  node("b", [B]),
  node("c", [C]),
  node("m", [M]),
  node("p", [P]),
  node("q", [Q]),
  node("d", [D]),
  edge("s", "a"),
  edge("a", "b"),
  edge("b", "c"),
  edge("c", "m"),
  edge("s", "b"), // long: widens b (level 1)
  edge("a", "c"), // long: widens c, entry shifts with b (level 2)
  edge("s", "p"),
  edge("p", "q"),
  edge("q", "d"),
  edge("d", "m"), // merge of c + d on moved parents (level 3)
)))
#let deep-p = placed(deep)
#assert(deep-p.settled, message: "deep cascade: widen loop did not settle")
#check-seats(deep, deep-p)

// --- no spurious widening -----------------------------------------------------
// A straight chain has no merges and no long edges: every node keeps its measured
// width exactly, and single-input fan-in never grows a node.
#let chain = layout(model((
  node("x", [X]),
  node("y", [Y]),
  node("z", [Z]),
  edge("x", "y"),
  edge("y", "z"),
)))
#let chain-p = placed(chain)
#assert(chain-p.settled, message: "chain: widen loop did not settle")
#for c in chain.cells {
  assert(
    chain-p.w.at(str(c.index)) == 3.0,
    message: "chain node " + str(c.index) + " widened without inputs to seat",
  )
}

// A page so the test target renders (the asserts above are the test).
#set page(width: auto, height: auto, margin: 0.2cm)
placement asserts passed
