#import "/src/flowchart/elements.typ": edge, group, node
#import "/src/flowchart/model.typ": model
#import "/src/flowchart/layout.typ": layout
#import "/src/flowchart/place.typ": label-spots, place
#import "/src/flowchart/crossing.typ": count-crossings

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
  group-pad: 0.35,
  title-room: 0.55,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
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
  // one, else its allocated exit column (several departures), else its
  // projected entry (spread exit toward the target when the parent forks,
  // clamped to 0.7 of its half-width).
  let landing = (s, k) => {
    let seat = p.dseat.at(str(s) + ">" + k, default: none)
    if seat != none { seat.x } else {
      p.dexit.at(str(s) + ">" + k, default: {
        let sx = p.x.at(str(s))
        let aim = if fano.at(str(s), default: 0) == 1 { sx } else { p.x.at(k) }
        let half = 0.7 * p.w.at(str(s)) / 2
        sx + calc.max(calc.min(aim - sx, half), -half)
      })
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
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
// The gap holds one track per bent tail: at least a stub at both faces and a
// lane between neighbours — and no two tails may share a height.
#assert(
  gap-above(2) >= 2 * tok.stub + (off-tails.len() - 1) * tok.lane-gap - 0.001,
  message: "trafficked gap did not grow for its tracks",
)
#for i in range(off-tails.len()) {
  for j in range(i + 1, off-tails.len()) {
    assert(
      calc.abs(off-tails.at(i) - off-tails.at(j)) >= tok.lane-gap - 0.001,
      message: "two bent tails share a height in one gap",
    )
  }
}

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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
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

// --- exit allocation: several departures leave at distinct points -------------
// The feed shape (one direct child plus two long corridors from one source):
// without allocation, a lone direct edge and every long edge all exit at the
// node's centre and draw as one line until they diverge. Each must get its own
// exit column on the face, a pitch apart, and the two corridors must fan at
// distinct heights below the node so their horizontal runs never overlie.
#let exf = layout(model((
  node("s", [S]),
  node("a", [A]),
  node("c", [C]),
  node("d", [D]),
  edge("s", "a"),
  edge("a", "c"),
  edge("a", "d"),
  edge("s", "c"), // rank 0 -> 2: long
  edge("s", "d"), // rank 0 -> 2: long
)))
#assert.eq(exf.edges.slice(3).map(e => e.kind), ("long", "long"))
#let exf-p = placed(exf)
#let exf-exits = (
  exf-p.dexit.at("0>1"),
  exf-p.route.at("3").exit,
  exf-p.route.at("4").exit,
)
// The allocation's own pitch and face bounds, from the same tokens.
#let ex-pitch = calc.min(tok.node-gap / 2, (3.0 - 2 * tok.pad-x) / 4)
#let ex-check(p, exits, msg) = {
  for i in range(exits.len()) {
    for j in range(i + 1, exits.len()) {
      assert(
        calc.abs(exits.at(i) - exits.at(j)) >= ex-pitch - 0.01,
        message: msg + ": exits " + str(i) + "," + str(j) + " collide",
      )
    }
    assert(
      calc.abs(exits.at(i) - p.x.at("0")) <= 3.0 / 2 - tok.pad-x + 0.01,
      message: msg + ": exit " + str(i) + " left the source face",
    )
  }
}
#ex-check(exf-p, exf-exits, "feed")
#assert(
  calc.abs(exf-p.route.at("3").hy - exf-p.route.at("4").hy)
    >= tok.lane-gap - 0.01,
  message: "long departures share a horizontal height",
)

// The firewall shape (two directs plus a long): spread direct exits used to
// saturate at the same 0.7-clamp flank for far same-side targets, and the
// long still left at the centre. All three must depart apart.
#let exw = layout(model((
  node("s", [S]),
  node("t1", [T1]),
  node("t2", [T2]),
  node("z", [Z]),
  edge("s", "t1"),
  edge("s", "t2"),
  edge("t1", "z"),
  edge("s", "z"), // rank 0 -> 2: long
)))
#assert.eq(exw.edges.last().kind, "long")
#let exw-p = placed(exw)
#ex-check(
  exw-p,
  (
    exw-p.dexit.at("0>1"),
    exw-p.dexit.at("0>2"),
    exw-p.route.at("3").exit,
  ),
  "firewall",
)

// --- crossing-aware routing: the cloud-deployment shape ------------------------
// One source forks to three near targets and drops a long edge two ranks down
// to a far store. Routed blind (each formula alone), the long edge's corridor
// pierced the email-bender's sideways run and its head jog was pierced by the
// bender's drop — two avoidable crossings, the user-reported shape. The
// corridor sweep and the per-gap track allocator must plan zero. Diagrams that
// are already crossing-free never move (the sweep exits on a zero score, and
// candidate ties keep the legacy pick) — pinned by every other case in this
// file holding its positions.
#let cloud = layout(model((
  node("ing", [I]),
  node("app", [A]),
  node("email", [E]),
  node("batch", [J]),
  node("redis", [R]),
  node("pg", [P]),
  edge("ing", "app"),
  edge("app", "email"),
  edge("app", "batch"),
  edge("app", "redis"),
  edge("app", "pg"), // rank 1 -> 3: long
  edge("batch", "pg"),
  edge("redis", "pg"),
)))
#assert.eq(cloud.edges.at(4).kind, "long")
#let cloud-p = place(
  sizes(cloud),
  cloud.edges,
  cloud.ranks,
  node-gap: 1.0, // wide rows: the interior gaps become corridor candidates
  rank-gap: tok.rank-gap,
  pad-x: tok.pad-x,
  back-margin: tok.back-margin,
  max-reach: tok.max-reach,
  widen-skew: tok.widen-skew,
  edge-clearance: tok.edge-clearance,
  lane-gap: tok.lane-gap,
  stub: tok.stub,
  margin-step: tok.margin-step,
  group-pad: tok.group-pad,
  title-room: tok.title-room,
)
#assert.eq(
  count-crossings(cloud-p.plan.values()),
  0,
  message: "the cloud shape still plans a crossing",
)
// The resolution must be one the engine owns: the corridor moved out of the
// bender's span, or the bender's run was stacked above the head jog.
#let cloud-r = cloud-p.route.at("4")
#if "1>2" in cloud-p.dseat {
  let ds = cloud-p.dseat.at("1>2")
  let eex = cloud-p.dexit.at("1>2")
  let (lo, hi) = (calc.min(ds.x, eex), calc.max(ds.x, eex))
  assert(
    cloud-r.cx <= lo + 0.01
      or cloud-r.cx >= hi - 0.01
      or ds.ay > cloud-r.hy + 0.01,
    message: "neither the sweep nor the allocator resolved the cloud crossing",
  )
  // Band fit: allocated heights keep a stub-length straight at both faces.
  let btop = cloud-p.y.at("1") - 0.5
  let bbot = cloud-p.y.at("2") + 0.5
  for h in (ds.ay, cloud-r.hy) {
    assert(
      h <= btop - tok.stub + 0.001 and h >= bbot + tok.stub - 0.001,
      message: "a track sits closer than a stub to a rank face",
    )
  }
}

// --- groups: hulls wrap members, outsiders stay out, corridors detour ----------
// A nested pair (inner ⊂ outer) plus an outsider whose parent sits in the
// group — packing wants it inside the band — and a long edge with no business
// in the box. The hull must wrap members with pad to spare, the parent must
// wrap the child, the outsider must be pushed clear, and the corridor must
// route around the band.
#let grouped = layout(model((
  node("a", [A]),
  node("f", [F]),
  node("e", [E]),
  node("b", [B]),
  node("c", [C]),
  node("d", [D]),
  edge("a", "b"),
  edge("f", "c"),
  edge("b", "d"),
  edge("c", "d"),
  edge("e", "d"),
  group("inner", [In], "a", "b"),
  group("outer", [Out], "inner", "f"),
)))
#let grouped-p = place(
  sizes(grouped),
  grouped.edges,
  grouped.ranks,
  // The inner group carries a measured title far wider than its members:
  // its box must widen to hold it rather than let the name overflow.
  groups: grouped.groups.map(g => if g.id == "inner" { (..g, tw: 9.0) } else {
    g
  }),
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
)
#assert(grouped-p.settled, message: "grouped graph did not settle")
#let ih = grouped-p.hulls.at("inner")
#let oh = grouped-p.hulls.at("outer")
// a(0) and b(3) sit inside the inner hull with the pad to spare.
#for i in ("0", "3") {
  assert(
    grouped-p.x.at(i) - 1.5 >= ih.x0 + tok.group-pad - 0.01
      and grouped-p.x.at(i) + 1.5 <= ih.x1 - tok.group-pad + 0.01,
    message: "member " + i + " leaks from the inner hull",
  )
}
// The parent wraps the child, a pad outside it, with its own title band.
#assert(oh.x0 <= ih.x0 - tok.group-pad + 0.01, message: "outer x0 too tight")
#assert(oh.x1 >= ih.x1 + tok.group-pad - 0.01, message: "outer x1 too tight")
#assert(
  oh.y1 >= ih.y1 + tok.group-pad + tok.title-room - 0.01,
  message: "outer title band missing above the inner box",
)
// The outsider c(4) — whose parent f is *in* the box, so packing pulls it
// toward the band — ends up fully outside the outer hull, with the border's
// clear channel (`group-pad`) to spare so it never touches the line.
#assert(
  grouped-p.x.at("4") - 1.5 >= oh.x1 + tok.group-pad - 0.01
    or grouped-p.x.at("4") + 1.5 <= oh.x0 - tok.group-pad + 0.01,
  message: "outsider touches the group box border",
)
// The unrelated long edge e(2) -> d(5) keeps its corridor out of the band.
#let gcx = grouped-p.route.at("4").cx
#assert(
  gcx <= oh.x0 + 0.01 or gcx >= oh.x1 - 0.01,
  message: "unrelated corridor runs through the group box",
)
// The inner box is at least as wide as its title.
#assert(
  ih.x1 - ih.x0 >= 9.0 + tok.group-pad - 0.01,
  message: "box narrower than its title",
)

// Sibling boxes can abut, and a node between them (a merge of both groups'
// outputs, under a wide member whose band covers it) must escape the *merged*
// band — escaping one box into the other and being bounced back forever was
// how a node got stranded inside a box.
#let sib = layout(model((
  node("a1", [A1]),
  node("b1", [B1]),
  node("a2", [A2]),
  node("o", [O]),
  node("b2", [B2]),
  edge("a1", "a2"),
  edge("b1", "b2"),
  edge("a1", "o"),
  edge("b1", "o"),
  group("A", [A], "a1", "a2"),
  group("B", [B], "b1", "b2"),
)))
#let sib-p = place(
  sizes(sib).map(c => if c.id == "a1" { (..c, w: 8.0) } else { c }),
  sib.edges,
  sib.ranks,
  groups: sib.groups,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
)
#let oha = sib-p.w.at("3") / 2
#for gid in ("A", "B") {
  let h = sib-p.hulls.at(gid)
  assert(
    sib-p.x.at("3") - oha >= h.x1 + tok.group-pad - 0.01
      or sib-p.x.at("3") + oha <= h.x0 - tok.group-pad + 0.01,
    message: "outsider stranded in sibling band " + gid,
  )
}
// Side-by-side sibling boxes keep daylight between their borders.
#assert(
  sib-p.hulls.at("B").x0 - sib-p.hulls.at("A").x1 >= tok.group-pad - 0.01,
  message: "sibling boxes touch",
)

// A corridor prefers a clear channel *between* row-mates over fleeing to the
// row's far edge: the source and target columns are blocked by m, but a wide
// gap runs beside it, all inside one box — the corridor must stay in the box.
#let chan = layout(model((
  node("s", [S]),
  node("m", [M]),
  node("r", [R]),
  node("t", [T]),
  edge("s", "m"),
  edge("m", "t"),
  edge("r", "t"),
  edge("s", "t"),
  group("box", [Box], "s", "m", "r", "t"),
)))
#let chan-p = place(
  sizes(chan, w: 4.0),
  chan.edges,
  chan.ranks,
  groups: chan.groups,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
)
// s->t is the fourth edge (index 3, long). Its corridor must run inside the
// box's band, not outside the diagram.
#let chan-h = chan-p.hulls.at("box")
#let chan-cx = chan-p.route.at("3").cx
#assert(
  chan-cx >= chan-h.x0 - 0.01 and chan-cx <= chan-h.x1 + 0.01,
  message: "corridor fled the box instead of using an interior gap",
)

// --- segmented corridors: member edges stay inside their box -------------------
// One wide member tiles its whole rank (its footprint plus clearance exceeds
// the box's pads), so the bypass edge a -> b has no straight in-box column.
// It must take an inside-border channel — segmentation triggers, every column
// stays in the hull, and the box widens by the reserved lane.
#let chanbox = layout(model((
  node("a", [A]),
  node("m", [M]),
  node("b", [B]),
  edge("a", "m"),
  edge("m", "b"),
  edge("a", "b"),
  group("box", [Box], "a", "m", "b"),
)))
#let chanbox-p = place(
  sizes(chanbox).map(c => if c.id == "m" { (..c, w: 9.0) } else { c }),
  chanbox.edges,
  chanbox.ranks,
  groups: chanbox.groups,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
)
// a->b is the third edge (index 2, long, crossing the tiled rank). The
// reservation widens the box; the rerouted corridor then fits inside it —
// straight if the widened band allows, segmented otherwise — never outside.
#let chanbox-h = chanbox-p.hulls.at("box")
#let chanbox-r = chanbox-p.route.at("2")
#for c in chanbox-r.at("cols", default: (chanbox-r.cx,)) {
  assert(
    c >= chanbox-h.x0 - 0.01 and c <= chanbox-h.x1 + 0.01,
    message: "member corridor column "
      + str(calc.round(c, digits: 2))
      + " left the box",
  )
}
// The box grew by the reserved channel lane on one side: its width exceeds
// the wide member plus pads by at least a lane.
#assert(
  chanbox-h.x1 - chanbox-h.x0 >= 9.0 + 2 * tok.group-pad + tok.lane-gap - 0.01,
  message: "box did not widen for its reserved channel",
)

// Two crossed ranks whose clear gaps sit on opposite sides: no single column
// threads both, so the bypass a -> b must genuinely step between columns —
// `cols` present, columns distinct, all inside the box.
#let zig = layout(model((
  node("a", [A]),
  node("m1", [M1]),
  node("r1", [R1]),
  node("l2", [L2]),
  node("m2", [M2]),
  node("b", [B]),
  edge("a", "m1"),
  edge("a", "r1"),
  edge("m1", "l2"),
  edge("r1", "m2"),
  edge("l2", "b"),
  edge("m2", "b"),
  edge("a", "b"),
  group("box", [Box], "a", "m1", "r1", "l2", "m2", "b"),
)))
#let zig-p = place(
  sizes(zig).map(c => if c.id in ("m1", "m2") { (..c, w: 8.0) } else { c }),
  zig.edges,
  zig.ranks,
  groups: zig.groups,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
)
// a->b is the seventh edge (index 6, long, crossing ranks 1 and 2).
#let zig-h = zig-p.hulls.at("box")
#let zig-r = zig-p.route.at("6")
#for c in zig-r.at("cols", default: (zig-r.cx,)) {
  assert(
    c >= zig-h.x0 - 0.01 and c <= zig-h.x1 + 0.01,
    message: "zig corridor column left the box",
  )
}

// Two member bypass edges forced into channels on opposite sides: this shape
// crashed the router (the widened borders swallowed every fallback corridor
// candidate) and, with both on one side, drew two lines on one column. It
// must place cleanly, with every channel column distinct and in-band.
#let twochan = layout(model((
  node("s", [S]),
  node("ba", [BA]),
  node("bb", [BB]),
  node("t1", [T1]),
  node("t2", [T2]),
  edge("s", "ba"),
  edge("ba", "bb"),
  edge("bb", "t1"),
  edge("bb", "t2"),
  edge("s", "t1"),
  edge("s", "t2"),
  group("box", [Box], "s", "ba", "bb", "t1", "t2"),
)))
#let twochan-p = place(
  sizes(twochan).map(c => if c.id in ("ba", "bb") { (..c, w: 8.0) } else {
    c
  }),
  twochan.edges,
  twochan.ranks,
  groups: twochan.groups,
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
  group-pad: tok.group-pad,
  title-room: tok.title-room,
)
#let twochan-box = twochan-p.hulls.at("box")
#let twochan-cols = (
  ("4", "5")
    .filter(ei => ei in twochan-p.route)
    .map(ei => {
      let r = twochan-p.route.at(ei)
      r.at("cols", default: (r.cx,))
    })
)
#for cols in twochan-cols {
  for c in cols {
    assert(
      c >= twochan-box.x0 - 0.01 and c <= twochan-box.x1 + 0.01,
      message: "bypass corridor left the box",
    )
  }
}
// Where both routes cross the same ranks, no two of their columns coincide.
#if twochan-cols.len() == 2 {
  for ca in twochan-cols.at(0) {
    for cb in twochan-cols.at(1) {
      assert(
        calc.abs(ca - cb) >= 0.015,
        message: "two corridors share a column",
      )
    }
  }
}

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
