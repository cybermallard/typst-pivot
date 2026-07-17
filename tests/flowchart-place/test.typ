#import "/src/flowchart/elements.typ": edge, node
#import "/src/flowchart/model.typ": model
#import "/src/flowchart/layout.typ": layout
#import "/src/flowchart/place.typ": label-spots, place

// Placement is pure math over measured sizes, so it is asserted numerically:
// fabricated sizes stand in for label measurement and make every check
// deterministic. The invariant under test is the one that broke (a cascaded
// widening left a merge narrower than its inputs' final positions): after
// placement, every node spans each of its seated inputs with `pad-x` to spare.

#let tok = (
  node-gap: 0.7,
  rank-gap: 1.3,
  pad-x: 0.45,
  back-margin: 0.6,
  back-gap: 0.45,
  max-reach: 6.0,
  widen-skew: 0.7,
  edge-clearance: 0.45,
  lane-gap: 0.45,
  stub: 0.6,
  margin-step: 0.35,
)

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
  max-reach: tok.max-reach,
  widen-skew: tok.widen-skew,
  edge-clearance: tok.edge-clearance,
  lane-gap: tok.lane-gap,
  stub: tok.stub,
  margin-step: tok.margin-step,
)

// The landing invariant: spanning is an optimization, landing is the
// guarantee. Every input — direct or long — must land ON its target's face:
// an on-face parent at its own column, an off-face one via its allocated seat
// (`dseat`), and every long entry via its route. Widths themselves are bounded
// by the skew and reach caps.
#let check-seats(g, p) = {
  let slack = 0.01
  let din = (:)
  let fano = (:)
  for e in g.edges {
    if e.kind == "direct" {
      din.insert(str(e.to), din.at(str(e.to), default: ()) + (e.from,))
      fano.insert(str(e.from), fano.at(str(e.from), default: 0) + 1)
    }
  }
  // A direct parent's landing mirrors the placement model: its seat if it has
  // one, else its projected entry (spread exit toward the target when the
  // parent forks, clamped to 0.7 of its half-width).
  let landing = (s, k) => {
    let seat = p.dseat.at(str(s) + ">" + k, default: none)
    if seat != none { seat.x } else {
      let sx = p.x.at(str(s))
      let aim = if fano.at(str(s), default: 0) == 1 { sx } else { p.x.at(k) }
      let half = 0.7 * p.w.at(str(s)) / 2
      sx + calc.max(calc.min(aim - sx, half), -half)
    }
  }
  // The face inset mirrors placement: pad-x, capped at a quarter extent so a
  // cross-narrow face keeps room for seats.
  let face-half = k => {
    let w = p.w.at(k)
    w / 2 - calc.min(tok.pad-x, w / 4)
  }
  for (k, parents) in din {
    for s in parents {
      assert(
        calc.abs(landing(str(s), k) - p.x.at(k)) <= face-half(k) + slack,
        message: "input "
          + str(s)
          + " into "
          + k
          + " does not land on the face",
      )
    }
  }
  for (ei, e) in g.edges.enumerate() {
    if e.kind == "long" {
      let r = p.route.at(str(ei))
      assert(
        calc.abs(r.entry - p.x.at(str(e.to))) <= face-half(str(e.to)) + slack,
        message: "long entry into node " + str(e.to) + " lands outside it",
      )
    }
  }
  for c in g.cells {
    assert(
      p.w.at(str(c.index))
        <= calc.max(3.0, 2 * (tok.max-reach + tok.pad-x)) + slack,
      message: "node " + str(c.index) + " exceeds the absolute width ceiling",
    )
  }
  // No two arrows may land on the same spot of a face: collect every landing
  // per target (parent columns or their seats, long entries) and require
  // strict pairwise separation.
  let landings = (:)
  for (ei, e) in g.edges.enumerate() {
    let k = str(e.to)
    if e.kind == "direct" {
      landings.insert(
        k,
        landings.at(k, default: ())
          + (
            landing(str(e.from), k),
          ),
      )
    } else if e.kind == "long" {
      landings.insert(
        k,
        landings.at(k, default: ())
          + (
            p.route.at(str(ei)).entry,
          ),
      )
    }
  }
  for (k, ls) in landings {
    for i in range(ls.len()) {
      for j in range(i + 1, ls.len()) {
        assert(
          calc.abs(ls.at(i) - ls.at(j)) >= 0.015,
          message: "two arrows land on the same spot of node " + k,
        )
      }
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

// --- unanchored source: aligns over its corridor ------------------------------
// The gallery's ransomware shape: `backups` (index 9) has no direct edges, only
// a long edge deep into the spine. It must chase its corridor to a dead-straight
// drop — node column == corridor == entry — and move no spine column doing it.
// Varied widths matter here: the wide mid-rank rows are what force the corridor
// off the packed position, so uniform sizes would pass vacuously.
#let ransom = layout(model((
  node("in", [I]),
  node("val", [V], shape: "diamond"),
  node("scope", [S], shape: "parallelogram"),
  node("fp", [F]),
  node("spread", [P], shape: "diamond"),
  node("iso", [N]),
  node("single", [H]),
  node("erad", [E]),
  node("restore", [R]),
  node("backups", [B], shape: "cylinder"), // 9 — unanchored
  node("verify", [C], shape: "diamond"),
  node("out", [O], shape: "rounded"),
  edge("in", "val"),
  edge("val", "scope"),
  edge("val", "fp"),
  edge("scope", "spread"),
  edge("spread", "iso"),
  edge("spread", "single"),
  edge("iso", "erad"),
  edge("single", "erad"),
  edge("erad", "restore"),
  edge("backups", "restore"), // long: rank 0 -> deep
  edge("restore", "verify"),
  edge("verify", "out"),
  edge("verify", "spread"), // back
  edge("fp", "out"), // long
)))
#let ransom-w = (
  "0": 3.9,
  "1": 4.7,
  "2": 4.2,
  "3": 4.4,
  "4": 5.2,
  "5": 4.5,
  "6": 2.6,
  "7": 3.3,
  "8": 3.6,
  "9": 2.7,
  "10": 5.6,
  "11": 4.6,
)
#let ransom-p = place(
  ransom.cells.map(c => (..c, w: ransom-w.at(str(c.index)), h: 1.0, th: 1.0)),
  ransom.edges,
  ransom.ranks,
  node-gap: tok.node-gap,
  rank-gap: tok.rank-gap,
  pad-x: tok.pad-x,
  back-margin: tok.back-margin,
  max-reach: tok.max-reach,
  widen-skew: tok.widen-skew,
  edge-clearance: tok.edge-clearance,
  lane-gap: tok.lane-gap,
  stub: tok.stub,
  margin-step: tok.margin-step,
)
#assert(ransom-p.settled, message: "ransom: widen loop did not settle")
#check-seats(ransom, ransom-p)
// The long-edge index for backups -> restore, then the straight-drop asserts.
#let bei = str(
  ransom
    .edges
    .enumerate()
    .find(((ei, e)) => e.kind == "long" and e.from == 9)
    .at(0),
)
#assert(
  calc.abs(ransom-p.x.at("9") - ransom-p.route.at(bei).cx) <= 0.02,
  message: "backups did not align over its corridor",
)
// The feed is one-sided (restore's only other neighbour is the spine), so the
// skew cap stops restore widening toward it: restore keeps its measured width
// and the feed's straight drop bends into a seat on the face at the end.
#assert(
  ransom-p.w.at("8") == ransom-w.at("8"),
  message: "skew cap failed: restore widened toward a one-sided feed",
)
// Spine immunity: the chase moved no spine column.
#for pair in (("7", "8"), ("8", "10"), ("10", "11")) {
  assert(
    calc.abs(ransom-p.x.at(pair.at(0)) - ransom-p.x.at(pair.at(1))) <= 0.02,
    message: "spine column " + pair.at(0) + "/" + pair.at(1) + " moved",
  )
}

// --- unanchored source with several feeds: keeps today's behaviour, settles.
// Two targets widening toward one shared column between them push each other
// apart forever, so a several-edged feed neither chases nor reorders — it holds
// its declared slot and its edges jog as usual. The placement must settle.
#let feed = layout(model((
  node("u", [U]), // 0 — unanchored, feeds both chains mid-way
  node("a0", [A0]),
  node("a1", [A1]),
  node("a2", [A2]),
  node("a3", [A3]),
  node("b0", [B0]),
  node("b1", [B1]),
  node("b2", [B2]),
  node("b3", [B3]),
  edge("a0", "a1"),
  edge("a1", "a2"),
  edge("a2", "a3"),
  edge("b0", "b1"),
  edge("b1", "b2"),
  edge("b2", "b3"),
  edge("u", "a2"), // long
  edge("u", "b2"), // long
)))
#let feed-p = placed(feed)
#assert(feed-p.settled, message: "feed: widen loop did not settle")
#check-seats(feed, feed-p)
// No reordering for a several-edged feed: it holds its declared slot.
#assert.eq(feed.cells.at(0).order, 0)

// --- dense fan-in: every arrow gets its own seat and lane ---------------------
// A SIEM-shaped sink: three direct parents plus two long feeds. All five
// attachment columns must be pairwise spaced, and the two long corridors must
// not share a lane (or one of them owns a straight seated drop).
#let dense = layout(model((
  node("p0", [P0]),
  node("p1", [P1]),
  node("p2", [P2]),
  node("q0", [Q0]),
  node("q1", [Q1]),
  node("q2", [Q2]),
  node("r0", [R0]),
  node("r1", [R1]),
  node("r2", [R2]),
  node("m", [M]),
  edge("p0", "p1"),
  edge("p1", "p2"),
  edge("q0", "q1"),
  edge("q1", "q2"),
  edge("r0", "r1"),
  edge("r1", "r2"),
  edge("p2", "m"),
  edge("q2", "m"),
  edge("r2", "m"),
  edge("p0", "m"), // long
  edge("q1", "m"), // long
)))
#let dense-p = placed(dense)
#assert(dense-p.settled, message: "dense: widen loop did not settle")
#let longs = (
  dense
    .edges
    .enumerate()
    .filter(((ei, e)) => e.kind == "long")
    .map(((ei, e)) => dense-p.route.at(str(ei)))
)
#assert.eq(longs.len(), 2)
#let seats = (
  dense-p.x.at("2"),
  dense-p.x.at("5"),
  dense-p.x.at("8"),
  ..longs.map(r => r.entry),
)
#for i in range(seats.len()) {
  for j in range(i + 1, seats.len()) {
    assert(
      calc.abs(seats.at(i) - seats.at(j)) >= tok.node-gap / 2 - 0.01,
      message: "seats " + str(i) + "/" + str(j) + " collide on the merge face",
    )
  }
}
#let seated = r => calc.abs(r.cx - r.entry) < 0.01
#assert(
  seated(longs.at(0))
    or seated(longs.at(1))
    or calc.abs(longs.at(0).cx - longs.at(1).cx) >= tok.back-gap - 0.01,
  message: "two jogging corridors share a lane",
)
#if not seated(longs.at(0)) and not seated(longs.at(1)) {
  assert(
    calc.abs(longs.at(0).ay - longs.at(1).ay) > 0.01,
    message: "two jogging tails share an approach height",
  )
}

// --- off-centre merge: stays label-sized, everything bends to seats -----------
// m's three parents sit to one side because the wide z-branch shoves m off
// their middle. Symmetric widths would double that offset into a platter; the
// skew cap keeps m at its measured width, and the parents plus the long feed
// from s all bend into spaced seats at distinct approach heights (the mixed
// direct + long fan).
#let off = layout(model((
  node("s", [S]),
  node("p", [P]), // 1
  node("q", [Q]), // 2
  node("r", [R]), // 3
  node("m", [M]), // 4 — its centre is fought for by z1/z2 below
  node("z1", [Y]), // 5 — anchored under q
  node("z2", [W]), // 6 — anchored under r
  edge("s", "p"),
  edge("s", "q"),
  edge("s", "r"),
  edge("p", "m"),
  edge("q", "m"),
  edge("r", "m"),
  edge("q", "z1"),
  edge("r", "z2"),
  edge("s", "m"), // long feed
)))
#let off-w = (
  "0": 3.0,
  "1": 5.0,
  "2": 5.0,
  "3": 5.0,
  "4": 3.0,
  "5": 5.0,
  "6": 5.0,
)
#let off-p = place(
  off.cells.map(c => (..c, w: off-w.at(str(c.index)), h: 1.0, th: 1.0)),
  off.edges,
  off.ranks,
  node-gap: tok.node-gap,
  rank-gap: tok.rank-gap,
  pad-x: tok.pad-x,
  back-margin: tok.back-margin,
  max-reach: tok.max-reach,
  widen-skew: tok.widen-skew,
  edge-clearance: tok.edge-clearance,
  lane-gap: tok.lane-gap,
  stub: tok.stub,
  margin-step: tok.margin-step,
)
#assert(off-p.settled, message: "off-centre merge: widen loop did not settle")
#check-seats(off, off-p)
// The valid outer bound of the skew cap, from final geometry: the face may
// reach past its nearer side's inputs by at most `widen-skew` (raw inputs =
// parent columns + the feed's corridor).
#let off-feed = str(
  off.edges.enumerate().find(((ei, e)) => e.kind == "long").at(0),
)
#let off-in = (
  off-p.x.at("1"),
  off-p.x.at("2"),
  off-p.x.at("3"),
  off-p.route.at(off-feed).cx,
)
#let off-lr = off-p.x.at("4") - calc.min(..off-in)
#let off-rr = calc.max(..off-in) - off-p.x.at("4")
#assert(
  off-p.w.at("4")
    <= 2 * (calc.min(off-lr, off-rr) + tok.widen-skew) + 2 * tok.pad-x + 0.01,
  message: "off-centre merge widened beyond the skew bound",
)
// At least the far parent and the feed must bend (mixed direct + long
// benders), and same-side tails never share an approach height.
#let off-benders = (
  ("1", "2", "3")
    .map(s => (
      side: off-p.x.at(s) <= off-p.x.at("4"),
      d: off-p.dseat.at(s + ">4", default: none),
    ))
    .filter(b => b.d != none)
    .map(b => (side: b.side, ay: b.d.ay))
    + (
      if calc.abs(off-p.route.at(off-feed).cx - off-p.route.at(off-feed).entry)
        > 0.01 {
        (
          (
            side: off-p.route.at(off-feed).cx <= off-p.x.at("4"),
            ay: off-p.route.at(off-feed).ay,
          ),
        )
      } else { () }
    )
)
#assert(off-benders.len() >= 2, message: "off-centre merge: expected benders")
#for i in range(off-benders.len()) {
  for j in range(i + 1, off-benders.len()) {
    if off-benders.at(i).side == off-benders.at(j).side {
      assert(
        calc.abs(off-benders.at(i).ay - off-benders.at(j).ay) > 0.01,
        message: "two same-side bending tails share an approach height",
      )
    }
  }
}

// --- spacing: margins, adaptive gaps, pitch, stubs ----------------------------
// The off-centre graph doubles as the spacing probe: `m` (degree 4) holds its
// rank-mates further off than plain packing would; the gap its bent tails fan
// through grows to hold them at `lane-gap` pitch, entered by at least a
// `stub`-length drop; an untrafficked gap stays at `rank-gap`.
// m (degree 4) carries a two-step margin; its rank-mates z1/z2 (degree 2)
// carry none. Consecutive row spacing must include the margins.
#let off-m-margin = tok.margin-step * 2
#let off-row = (
  (off-p.x.at("4"), off-w.at("4"), off-m-margin),
  (off-p.x.at("5"), off-w.at("5"), 0),
  (off-p.x.at("6"), off-w.at("6"), 0),
).sorted(key: e => e.at(0))
#for i in range(off-row.len() - 1) {
  let (ax, aw, am) = off-row.at(i)
  let (bx, bw, bm) = off-row.at(i + 1)
  assert(
    bx - ax >= (aw + bw) / 2 + tok.node-gap + am + bm - 0.01,
    message: "busy node's rank-mate packed closer than its margin allows",
  )
}
// Tail heights: every bent tail sits at least `stub` above its target's face,
// consecutive same-side tails exactly `lane-gap` apart.
#let off-tails = off-benders.map(b => b.ay)
#let off-top = off-p.y.at("4") + 0.5
#for a in off-tails {
  assert(
    a - off-top >= tok.stub - 0.001,
    message: "tail drop shorter than stub",
  )
}
// The gap above m's rank grew to hold its fan; the gap above rank 1 (no bent
// tails) stays at rank-gap. Gap = distance between rank rows minus half-heights.
#let gap-above = r => {
  let above = off.cells.find(c => c.rank == r - 1)
  let here = off.cells.find(c => c.rank == r)
  (off-p.y.at(str(above.index)) - 0.5) - (off-p.y.at(str(here.index)) + 0.5)
}
// An untrafficked gap stays at rank-gap: the plain chain has no benders.
#assert(
  calc.abs(
    (chain-p.y.at("0") - 0.5) - (chain-p.y.at("1") + 0.5) - tok.rank-gap,
  )
    <= 0.001,
  message: "untrafficked gap changed",
)
#let off-nmax = calc.max(
  off-benders.filter(b => b.side).len(),
  off-benders.filter(b => not b.side).len(),
)
#assert(
  gap-above(2) >= 2 * (tok.stub + off-nmax * tok.lane-gap) - 0.001,
  message: "trafficked gap did not grow for its fan",
)

// --- crowded face: landings never coincide ------------------------------------
// Six parents into one target whose widening is capped tight (max-reach 1.2 →
// face ≈ 2.4 wide): the allocator must run out of gap-spaced slots and the
// respace must still keep every landing strictly distinct — including clear of
// any on-face parent column (the old respace ignored those and doubled up).
#let crowd = layout(model((
  node("s", [S]),
  node("p1", [A]),
  node("p2", [B]),
  node("p3", [C]),
  node("p4", [D]),
  node("p5", [E]),
  node("p6", [F]),
  node("m", [M]),
  edge("s", "p1"),
  edge("s", "p2"),
  edge("s", "p3"),
  edge("s", "p4"),
  edge("s", "p5"),
  edge("s", "p6"),
  edge("p1", "m"),
  edge("p2", "m"),
  edge("p3", "m"),
  edge("p4", "m"),
  edge("p5", "m"),
  edge("p6", "m"),
)))
#let crowd-p = place(
  sizes(crowd),
  crowd.edges,
  crowd.ranks,
  node-gap: tok.node-gap,
  rank-gap: tok.rank-gap,
  pad-x: tok.pad-x,
  back-margin: tok.back-margin,
  max-reach: 1.2,
  widen-skew: tok.widen-skew,
  edge-clearance: tok.edge-clearance,
  lane-gap: tok.lane-gap,
  stub: tok.stub,
  margin-step: tok.margin-step,
)
#assert(crowd-p.settled, message: "crowded face: widen loop did not settle")
#let crowd-landings = (
  ("1", "2", "3", "4", "5", "6").map(s => {
    let seat = crowd-p.dseat.at(s + ">7", default: none)
    if seat != none { seat.x } else { crowd-p.x.at(s) }
  })
)
#for i in range(crowd-landings.len()) {
  for j in range(i + 1, crowd-landings.len()) {
    assert(
      calc.abs(crowd-landings.at(i) - crowd-landings.at(j)) >= 0.015,
      message: "crowded face doubled up two arrows",
    )
  }
}

// --- narrow face: seats survive a cross-narrow target -------------------------
// A one-line box in a horizontal flow is barely wider than two pads (its cross
// extent is its measured height): with the face inset uncapped, the face
// collapsed to a point and every input's arrow landed on the same spot —
// doubled arrowheads. Narrow same-size cells reproduce the shape: a direct
// parent plus a long feed into t must keep clearly separate landings within
// t's capped-inset face.
#let narrow = layout(model((
  node("k", [K]),
  node("c", [C]),
  node("d", [D]),
  node("t", [T]),
  node("u", [U]),
  edge("k", "c"),
  edge("k", "d"),
  edge("c", "t"),
  edge("d", "u"),
  edge("k", "t"),
)))
#let narrow-p = place(
  sizes(narrow, w: 1.0),
  narrow.edges,
  narrow.ranks,
  node-gap: tok.node-gap,
  rank-gap: tok.rank-gap,
  pad-x: tok.pad-x,
  back-margin: tok.back-margin,
  max-reach: tok.max-reach,
  widen-skew: tok.widen-skew,
  edge-clearance: tok.edge-clearance,
  lane-gap: tok.lane-gap,
  stub: tok.stub,
  margin-step: tok.margin-step,
)
#check-seats(narrow, narrow-p)
// k=0, c=1, t=3; c->t is direct, k->t is the fifth edge (index 4, long).
#let narrow-direct = {
  let seat = narrow-p.dseat.at("1>3", default: none)
  if seat != none { seat.x } else { narrow-p.x.at("1") }
}
#assert(
  calc.abs(narrow-direct - narrow-p.route.at("4").entry) >= 0.15,
  message: "narrow face stacked its two arrows",
)

// --- label-spots: the pure collision solver ------------------------------------
// A free run keeps its midpoint exactly (no churn for sparse diagrams).
#let one = label-spots(
  ((segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2),),
  (),
  (),
  head-room: 0,
)
#assert.eq(one.at(0), (0, -2))
// Two labels wanting the same spot: the second slides along its run.
#let two = label-spots(
  (
    (segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2),
    (segs: ((0.1, 0, 0.1, -4),), hw: 0.4, hh: 0.2),
  ),
  (),
  (),
  head-room: 0,
)
#assert(
  calc.abs(two.at(0).at(0) - two.at(1).at(0)) >= 0.8
    or calc.abs(two.at(0).at(1) - two.at(1).at(1)) >= 0.4,
  message: "labels overlap",
)
// A node box over the midpoint pushes the label off it.
#let dodged = label-spots(
  ((segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2),),
  ((0, -2, 1.0, 0.5),),
  (),
  head-room: 0,
)
#assert(dodged.at(0) != (0, -2), message: "label sat on a node box")
// Another edge's line through the midpoint pushes the label off it — a spot
// there would knock the line out. The label's own line never does: it always
// sits on it.
#let crossed = label-spots(
  ((segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2, edge: 0),),
  (),
  ((edge: 1, box: (0, -2, 2.0, 0)),),
  head-room: 0,
)
#assert(crossed.at(0) != (0, -2), message: "label knocked out a foreign line")
#let own-line = label-spots(
  ((segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2, edge: 0),),
  (),
  ((edge: 0, box: (0, -2, 0, 2.0)),),
  head-room: 0,
)
#assert.eq(own-line.at(0), (0, -2))
// The label stays clear of its own arrow tip: with the middle of the run
// blocked by foreign lines, it slides *up* the run — the spot below is inside
// the tip's head-room and would sit the label on the arrowhead.
#let headed = label-spots(
  (
    (
      segs: ((0, 0, 0, -2),),
      hw: 0.4,
      hh: 0.2,
      edge: 0,
      tip: (0, -2),
    ),
  ),
  (),
  ((edge: 1, box: (0, -1, 2.0, 0)), (edge: 2, box: (0, -0.7, 2.0, 0))),
  head-room: 0.6,
)
#assert(
  calc.abs(headed.at(0).at(1) - (-0.4)) < 0.001,
  message: "label crowded its own arrowhead",
)
// The finer ring: with every coarse fraction blocked by a crossing line, the
// label threads the clean band near the run's start instead of dropping to
// the relaxed pass and knocking a line out.
#let threaded = label-spots(
  ((segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2, edge: 0),),
  (),
  (
    (edge: 1, box: (0, -2, 2.0, 0)),
    (edge: 2, box: (0, -1.4, 2.0, 0)),
    (edge: 3, box: (0, -2.6, 2.0, 0)),
    (edge: 4, box: (0, -0.8, 2.0, 0)),
    (edge: 5, box: (0, -3.2, 2.0, 0)),
  ),
  head-room: 0,
)
#assert(
  calc.abs(threaded.at(0).at(1) + 0.48) < 0.001,
  message: "finer ring did not thread the clean band",
)
// Graceful degradation: a wide label that can't clear a foreign line anywhere
// on its run gives up line cleanliness — never sits on the label already
// placed (the old fallback put it on the midpoint, straight over it).
#let relaxed = label-spots(
  (
    (segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2, edge: 0),
    (segs: ((0.5, 0, 0.5, -4),), hw: 1.0, hh: 0.2, edge: 1),
  ),
  (),
  ((edge: 2, box: (1.2, -2, 0, 2.0)),),
  head-room: 0,
)
#assert(
  calc.abs(relaxed.at(1).at(1) - relaxed.at(0).at(1)) >= 0.4,
  message: "crowded label fell back onto another label",
)
// A label never blankets a segment: the short preferred run can't keep line
// showing past both ends of the box, so the label moves to the long one.
#let swallowed = label-spots(
  ((segs: ((0, 0, 0, -0.5), (0, -0.5, 3, -0.5)), hw: 0.5, hh: 0.2),),
  (),
  (),
  head-room: 0,
)
#assert.eq(swallowed.at(0), (1.5, -0.5))

// An author's offset shifts the label from its auto spot exactly, and the
// moved rectangle is what the next label dodges.
#let nudged = label-spots(
  ((segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2, off: (0.3, 0.5)),),
  (),
  (),
  head-room: 0,
)
#assert.eq(nudged.at(0), (0.3, -1.5))
// A second label whose *preferred* spot is exactly the moved one must dodge
// it — proof the nudge reserved its new footprint, not the vacated auto
// position. Label 0 moves from y=-2 to y=-0.5; label 1's own midpoint is -0.5,
// so if the reservation sat at the vacated -2 (the bug), label 1 would land
// straight on the moved label 0. It must not.
#let nudged-pair = label-spots(
  (
    (segs: ((0, 0, 0, -4),), hw: 0.4, hh: 0.2, off: (0, 1.5)),
    (segs: ((0, 1.5, 0, -2.5),), hw: 0.4, hh: 0.2),
  ),
  (),
  (),
  head-room: 0,
)
#assert.eq(nudged-pair.at(0), (0, -0.5))
#assert(
  calc.abs(nudged-pair.at(1).at(1) - (-0.5)) >= 0.4,
  message: "second label sat on the nudged label's footprint",
)

// A page so the test target renders (the asserts above are the test).
#set page(width: auto, height: auto, margin: 0.2cm)
placement asserts passed
