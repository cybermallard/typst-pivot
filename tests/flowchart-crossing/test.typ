#import "/src/flowchart/crossing.typ": (
  count-crossings, order-tracks, pair-cost, seg-cross,
)

// The counter's definition of a crossing: a strict interior pass-through.
// Bends, T-junctions and collinear overlaps are joints, not crossings.
#assert(seg-cross((0, 0, 4, 0), (2, 2, 2, -2)), message: "plain cross missed")
#assert(
  not seg-cross((0, 0, 4, 0), (0, 0, 0, -2)),
  message: "shared endpoint (a bend) counted as a crossing",
)
#assert(
  not seg-cross((0, 0, 4, 0), (2, 0, 2, -2)),
  message: "T-junction counted as a crossing",
)
#assert(
  not seg-cross((0, 0, 4, 0), (1, 0, 3, 0)),
  message: "collinear overlap counted as a crossing",
)
#assert(
  not seg-cross((0, 0, 4, 0), (5, 1, 9, 1)),
  message: "parallel horizontals counted as a crossing",
)
#assert(
  not seg-cross((2, 1, 2, -1), (2, 3, 2, 0)),
  message: "two verticals counted as a crossing",
)

// Two staircase edges with exactly two pass-throughs: B's drop pierces A's
// horizontal, and B's horizontal pierces A's second drop.
#assert.eq(
  count-crossings((
    ((0, 0), (0, -2), (4, -2), (4, -4)),
    ((2, 0), (2, -3), (6, -3), (6, -4)),
  )),
  2,
)
// Same-polyline segments never count against each other.
#assert.eq(count-crossings((((0, 0), (0, -2), (4, -2), (4, -4)),)), 0)

// The canonical band shape (the cloud-deployment crossing): a run rising at
// its right end and dropping at its left, next to one shifted right. Stacked
// wrong (s above n) they cross twice; stacked right, never.
#let tn = (
  id: "n",
  edge: 0,
  kind: "dseat",
  gap: 1,
  x0: 1,
  x1: 3,
  ux: 3,
  dx: 1,
  legacy-y: -1.0,
)
#let ts = (
  id: "s",
  edge: 1,
  kind: "head",
  gap: 1,
  x0: 2,
  x1: 4,
  ux: 4,
  dx: 2,
  legacy-y: -0.5,
)
#assert.eq(pair-cost(tn, ts), 0)
#assert.eq(pair-cost(ts, tn), 2)
// A missing riser or dropper contributes nothing.
#assert.eq(pair-cost((..ts, dx: none), (..tn, ux: none)), 0)

// The allocator flips the legacy stacking to the crossing-free one…
#let flipped = order-tracks((ts, tn), ())
#assert.eq(flipped.order, ("n", "s"))
#assert(flipped.settled)
// …unless a hard constraint (a fan pair) forbids it…
#assert.eq(
  order-tracks((ts, tn), ((above: "s", below: "n"),)).order,
  ("s", "n"),
)
// …and an already-optimal order comes back unchanged.
#assert.eq(order-tracks((tn, ts), ()).order, ("n", "s"))

// Three mutually overlapping runs, handed over fully inverted: the greedy
// pass bubbles each into place across two rounds.
#let t1 = (
  id: "t1",
  edge: 0,
  kind: "head",
  gap: 1,
  x0: 0,
  x1: 3,
  ux: 3,
  dx: 0,
  legacy-y: -0.4,
)
#let t2 = (..t1, id: "t2", edge: 1, x0: 1, x1: 4, ux: 4, dx: 1)
#let t3 = (..t1, id: "t3", edge: 2, x0: 2, x1: 5, ux: 5, dx: 2)
#let inverted = order-tracks((t3, t2, t1), ())
#assert.eq(inverted.order, ("t1", "t2", "t3"))
#assert(inverted.settled)

// A page so the test target renders (the asserts above are the test).
#set page(width: auto, height: auto, margin: 0.2cm)
crossing asserts passed
