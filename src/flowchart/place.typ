// place: measured cells -> coordinates. Pure, no cetz — the geometric half of the
// flowchart pipeline. `layout` fixes each node's rank and order; `place` turns
// measured sizes into positions — relaxing each rank toward a straight spine,
// widening a merge target to seat its inputs, choosing each long edge's corridor,
// and aligning an unanchored node (one with no direct edges) over its corridors —
// and `render` owns measurement and drawing, which need the document context.
//
// cells: one dict per node; reads index, rank, order, w, h, th, shape (extra keys
//        are the caller's and pass through untouched). Sizes are canvas units.
// edges: the classified edges from `layout` (from, to, kind).
// ranks: the rank count from `layout`.
// The token arguments are canvas-unit numbers from the theme; all are required.
//
// Returns dicts keyed by str(node index) — `x`, `y`, `w` (heights are the
// caller's) — plus `route` (per long-edge index: cx, side-ok, entry), `fanout`
// (direct children per node), `hulls` (per group id: the box rectangle and
// nesting depth), and `settled`: whether the widen loop reached its
// fixed point within the bound. If it didn't, widths may under-span their inputs;
// the renderer's shape-aware attach still lands every edge on an outline.

#let place(
  cells,
  edges,
  ranks,
  groups: (),
  node-gap: none,
  rank-gap: none,
  pad-x: none,
  back-margin: none,
  max-reach: none,
  widen-skew: none,
  edge-clearance: none,
  lane-gap: none,
  stub: none,
  margin-step: none,
  group-pad: none,
  title-room: none,
) = {
  for (name, v) in (
    ("node-gap", node-gap),
    ("rank-gap", rank-gap),
    ("pad-x", pad-x),
    ("back-margin", back-margin),
    ("max-reach", max-reach),
    ("widen-skew", widen-skew),
    ("edge-clearance", edge-clearance),
    ("lane-gap", lane-gap),
    ("stub", stub),
    ("margin-step", margin-step),
    ("group-pad", group-pad),
    ("title-room", title-room),
  ) {
    assert(v != none, message: "place: `" + name + "` is required")
  }
  if cells.len() == 0 {
    return (
      x: (:),
      y: (:),
      w: (:),
      route: (:),
      fanout: (:),
      hulls: (:),
      settled: true,
    )
  }
  // Groups with at least one (transitive) node member get geometry; an empty
  // group renders nothing. `gp` is each node's enclosure path.
  let live-groups = groups.filter(g => g.nodes.len() > 0)
  let gp = (:)
  for c in cells { gp.insert(str(c.index), c.at("gpath", default: ())) }
  let gspan = (:)
  for g in live-groups {
    let rs = g.nodes.map(a => cells.at(a).rank)
    gspan.insert(g.id, (calc.min(..rs), calc.max(..rs)))
  }
  // Whether input `s` sits in a box that excludes node `t` across t's own
  // rank — such a box's band is ground t may never occupy, so t must not
  // widen toward s (the arrow bends into a seat instead).
  let boxed-off = (t, s) => {
    let pt = gp.at(str(t), default: ())
    let tr = cells.at(t).rank
    gp
      .at(str(s), default: ())
      .any(gid => (
        not pt.contains(gid)
          and {
            let sp = gspan.at(gid, default: none)
            sp != none and tr >= sp.at(0) and tr <= sp.at(1)
          }
      ))
  }
  // A group's horizontal band under the current positions: member nodes and
  // child bands wrapped with `group-pad` — and never narrower than its
  // measured title (`tw`, supplied by the renderer), so a long name can't
  // overflow its box. This mirrors the hull computation exactly (children
  // recursively, then pad, then the title minimum), and one helper feeds the
  // push-out sweep and the corridor obstacles, so obstacle math and the drawn
  // border can never disagree.
  let live-by-id = (:)
  for g in live-groups { live-by-id.insert(g.id, g) }
  // A self-loop draws a small return loop off the node's cross-axis side —
  // `node-gap * 0.7` deep, matching the renderer's self-edge branch — so a
  // box around such a node must reserve that room too.
  let selfy = (:)
  for e in edges {
    if e.kind == "self" { selfy.insert(str(e.from), true) }
  }
  let loop-room = a => if str(a) in selfy { node-gap * 0.7 } else { 0 }
  // `chan` reserves internal routing channels: per group id, (l:, r:) counts
  // of corridor lanes running just inside that border — each widens the band
  // by a lane. Threaded explicitly (closures capture by value) so every
  // consumer sees the same reservations.
  let gband-rec = (self, g, x, w, chan) => {
    let lo = calc.min(..g.nodes.map(a => x.at(str(a)) - w.at(str(a)) / 2))
    let hi = calc.max(..g.nodes.map(a => (
      x.at(str(a)) + w.at(str(a)) / 2 + loop-room(a)
    )))
    for m in g.members {
      if m in live-by-id {
        let cb = self(self, live-by-id.at(m), x, w, chan)
        lo = calc.min(lo, cb.lo)
        hi = calc.max(hi, cb.hi)
      }
    }
    let ch = chan.at(g.id, default: (l: 0, r: 0))
    lo -= group-pad + ch.l * lane-gap
    hi += group-pad + ch.r * lane-gap
    let want = g.at("tw", default: 0) + group-pad
    if hi - lo < want {
      let c = (lo + hi) / 2
      (lo: c - want / 2, hi: c + want / 2)
    } else { (lo: lo, hi: hi) }
  }
  // Reservations are set by the segmented-corridor pass below; closures
  // capture by value, so `ch` rides along as an argument everywhere.
  let gband = (g, x, w, ch) => gband-rec(gband-rec, g, x, w, ch)
  // The innermost box both endpoints of an edge share ((none) if unboxed or
  // in disjoint boxes): the deepest common prefix of their enclosure paths.
  let shared-box = (u, v) => {
    let pu = gp.at(str(u), default: ())
    let pv = gp.at(str(v), default: ())
    let c = 0
    while c < calc.min(pu.len(), pv.len()) and pu.at(c) == pv.at(c) {
      c += 1
    }
    if c == 0 { none } else { pu.at(c - 1) }
  }
  // Group borders lying between two rank-mates: the groups their enclosure
  // paths diverge over. Each border needs `group-pad` of room — plus a lane
  // per routing channel reserved inside it.
  let crossed-groups = (a, b) => {
    let pa = gp.at(str(a), default: ())
    let pb = gp.at(str(b), default: ())
    let c = 0
    while c < calc.min(pa.len(), pb.len()) and pa.at(c) == pb.at(c) {
      c += 1
    }
    pa.slice(c) + pb.slice(c)
  }
  let border-room = (a, b, ch) => crossed-groups(a, b)
    .map(gid => {
      let cc = ch.at(gid, default: (l: 0, r: 0))
      group-pad + (cc.l + cc.r) * lane-gap
    })
    .sum(default: 0)

  let wof = (:)
  let hof = (:)
  for c in cells {
    wof.insert(str(c.index), c.w)
    hof.insert(str(c.index), c.h)
  }

  // Automatic breathing room: a node's packing footprint grows with its edge
  // count — a busy hub holds its rank-mates (and passing corridors) further
  // off than a chain link does. Placement-only: the drawn face keeps `w`.
  let mof = (:)
  for c in cells { mof.insert(str(c.index), 0) }
  for e in edges {
    for k in (e.from, e.to) {
      mof.insert(str(k), mof.at(str(k)) + 1)
    }
  }
  for (k, deg) in mof {
    mof.insert(k, margin-step * calc.max(0, deg - 2))
  }

  // Nodes of each rank, in order; rank height is its tallest node.
  let order-in-rank = range(ranks).map(r => cells
    .filter(c => c.rank == r)
    .sorted(key: c => c.order)
    .map(c => c.index))
  let rank-h = order-in-rank.map(row => if row.len() > 0 {
    calc.max(..row.map(a => hof.at(str(a))))
  } else { 0 })
  // (Vertical positions are assigned late: the gap between two ranks adapts to
  // the edge traffic that must fan through it, which is only known once seats
  // are allocated.)

  // Neighbours across ranks, from the *direct* edges only — long/back edges route
  // on the side and shouldn't tug spine nodes out of line. (A node absent from
  // this map has no spine to be tugged out of; the widen loop below aligns it
  // over its long edges' corridors instead.)
  let nbr = (:)
  for e in edges {
    if e.kind == "direct" {
      nbr.insert(str(e.from), nbr.at(str(e.from), default: ()) + (e.to,))
      nbr.insert(str(e.to), nbr.at(str(e.to), default: ()) + (e.from,))
    }
  }

  // Direct and long inputs of each node. A merge widens to seat its direct inputs
  // straight and to reach the entry column of each long (side-arriving) input.
  let din = (:)
  let lin = (:)
  for (ei, e) in edges.enumerate() {
    if e.kind == "direct" {
      din.insert(str(e.to), din.at(str(e.to), default: ()) + (e.from,))
    } else if e.kind == "long" {
      lin.insert(
        str(e.to),
        lin.at(str(e.to), default: ()) + ((ei: ei, from: e.from),),
      )
    }
  }
  let median = xs => {
    let s = xs.sorted()
    let k = s.len()
    if k == 0 { 0 } else if calc.rem(k, 2) == 1 {
      s.at(calc.quo(k, 2))
    } else {
      (s.at(calc.quo(k, 2) - 1) + s.at(calc.quo(k, 2))) / 2
    }
  }

  // How many long edges each *unanchored* node (no direct edges) touches. With
  // several, the node has no column a corridor should prefer — preferring the
  // source diverges: the target widens toward the source's column while that
  // very widening repacks the ranks and drifts the column further away. Those
  // edges prefer a corridor near their target instead (see `corridor`).
  let lcount = (:)
  for e in edges {
    if e.kind == "long" {
      for k in (e.from, e.to) {
        if str(k) not in nbr {
          lcount.insert(str(k), lcount.at(str(k), default: 0) + 1)
        }
      }
    }
  }

  // Coordinate assignment: start centred by order, then relax each node toward the
  // median of its neighbours (aligning chains) while a forward and a backward pass
  // hold each rank's separation. Both preserve the minimum gap, so their average
  // does too — the spine straightens without nodes ever overlapping.
  //
  // Long and back edges don't tug *spine* nodes out of line — but an unanchored
  // node (no direct edges at all, e.g. a feed that only supplies distant steps)
  // has no line to be tugged out of. `cwant` carries such a node's current
  // target: the median of its long edges' corridor columns; it chases that
  // instead of staying wherever rank packing dropped it.
  let relax = (widths, cwant, ch) => {
    // Packing and separation see each node's margined footprint; a group
    // border between two rank-mates costs `group-pad` more (plus any routing
    // channels reserved inside it), reserving the room the hull's edge will
    // occupy.
    let pw = a => widths.at(str(a)) + 2 * mof.at(str(a))
    let x = (:)
    for r in range(ranks) {
      let row = order-in-rank.at(r)
      let gaps-in-row = range(calc.max(row.len() - 1, 0)).map(i => (
        node-gap + border-room(row.at(i), row.at(i + 1), ch)
      ))
      let total = (
        row.map(a => pw(a)).sum(default: 0)
          + gaps-in-row.sum(
            default: 0,
          )
      )
      let cx = -total / 2
      for (k, a) in row.enumerate() {
        x.insert(str(a), cx + pw(a) / 2)
        cx += pw(a) + gaps-in-row.at(k, default: 0)
      }
    }
    for pass in range(12) {
      let seq = if calc.rem(pass, 2) == 0 {
        range(ranks)
      } else {
        range(ranks - 1, -1, step: -1)
      }
      for r in seq {
        let row = order-in-rank.at(r)
        let k = row.len()
        if k == 0 { continue }
        let want = row.map(a => {
          let ns = nbr.at(str(a), default: ())
          if ns.len() > 0 { median(ns.map(nn => x.at(str(nn)))) } else if (
            str(a) in cwant
          ) {
            cwant.at(str(a))
          } else {
            x.at(str(a))
          }
        })
        let sep = i => (
          pw(row.at(i)) / 2
            + node-gap
            + border-room(row.at(i), row.at(i + 1), ch)
            + pw(row.at(i + 1)) / 2
        )
        let xf = (want.at(0),)
        for i in range(1, k) {
          xf.push(calc.max(want.at(i), xf.at(i - 1) + sep(i - 1)))
        }
        let xb = range(k).map(_ => 0)
        xb.at(k - 1) = want.at(k - 1)
        for i in range(k - 2, -1, step: -1) {
          xb.at(i) = calc.min(want.at(i), xb.at(i + 1) - sep(i))
        }
        for i in range(k) {
          x.insert(str(row.at(i)), (xf.at(i) + xb.at(i)) / 2)
        }
      }
    }
    x
  }

  let shapeof = (:)
  let rankof = (:)
  for c in cells {
    shapeof.insert(str(c.index), c.shape)
    rankof.insert(str(c.index), c.rank)
  }

  // The clearest vertical corridor for a long edge u -> v under the current widths:
  // the candidate x that no node in the crossed ranks blocks, chosen closest to the
  // source's own column so the edge drops straight when that column is clear (and
  // only jogs when it isn't). Candidates are the endpoints (or, for a side exit, the
  // source's flanks), the gaps just outside each crossed rank, and just outside the
  // diagram — the last is always clear, so a corridor always exists. With `side-exit`
  // (a decision leaving by a side vertex) the corridor must sit outside the source,
  // its run at u.y clear of u's rank-mates; returns none if none does (caller falls
  // back to a bottom exit).
  let corridor = (ui, vi, side-exit, prefer-target, x, w, ch) => {
    let ur = rankof.at(str(ui))
    let vr = rankof.at(str(vi))
    let ux = x.at(str(ui))
    let uw = w.at(str(ui))
    let vx = x.at(str(vi))
    // A routed edge keeps `edge-clearance` from every node it passes, measured
    // from the node's margined footprint — busy hubs hold corridors further off.
    let hw = a => w.at(str(a)) / 2 + mof.at(str(a))
    let minx = calc.min(..cells.map(c => (
      x.at(str(c.index)) - w.at(str(c.index)) / 2
    )))
    let maxx = calc.max(..cells.map(c => (
      x.at(str(c.index)) + w.at(str(c.index)) / 2
    )))
    let occupied = ()
    let cands = (vx, minx - back-margin, maxx + back-margin)
    cands += if side-exit {
      (ux - uw / 2 - edge-clearance, ux + uw / 2 + edge-clearance)
    } else { (ux,) }
    for r in range(calc.min(ur, vr) + 1, calc.max(ur, vr)) {
      let row = order-in-rank.at(r)
      for a in row {
        occupied.push((
          x.at(str(a)) - hw(a) - edge-clearance,
          x.at(str(a)) + hw(a) + edge-clearance,
        ))
      }
      if row.len() > 0 {
        cands.push(
          calc.min(..row.map(a => x.at(str(a)) - hw(a))) - edge-clearance,
        )
        cands.push(
          calc.max(..row.map(a => x.at(str(a)) + hw(a))) + edge-clearance,
        )
      }
      // A wide-enough gap *between* two row-mates is a corridor column too —
      // without these, a blocked source column sends the edge fleeing to the
      // row's far edge (or clean outside the diagram) when a clear channel
      // runs right next to it.
      for i in range(calc.max(row.len() - 1, 0)) {
        let lo = x.at(str(row.at(i))) + hw(row.at(i))
        let hi = x.at(str(row.at(i + 1))) - hw(row.at(i + 1))
        if hi - lo >= 2 * edge-clearance { cands.push((lo + hi) / 2) }
      }
    }
    // A group's box blocks corridors that have no business inside it: when
    // neither endpoint is a member and the box lies across the crossed ranks,
    // the hull's band joins the obstacles (an edge with an endpoint inside
    // must cross the border, and does so near that endpoint's own column). A
    // corridor that does belong inside may run through the box — but not
    // *along* its border line, so each border keeps a lane's width clear.
    for g in live-groups {
      let rs = g.nodes.map(a => rankof.at(str(a)))
      if (
        calc.max(..rs) < calc.min(ur, vr) or calc.min(..rs) > calc.max(ur, vr)
      ) { continue }
      let b = gband(g, x, w, ch)
      if (
        gp.at(str(ui), default: ()).contains(g.id)
          or gp.at(str(vi), default: ()).contains(g.id)
      ) {
        occupied.push((b.lo - lane-gap / 2, b.lo + lane-gap / 2))
        occupied.push((b.hi - lane-gap / 2, b.hi + lane-gap / 2))
        // Candidates just clear of the border lanes: when a box's interior is
        // fully tiled, these keep a corridor findable — a widened border can
        // otherwise swallow even the outside-the-diagram fallback columns,
        // leaving no candidate at all.
        cands.push(b.lo - lane-gap)
        cands.push(b.hi + lane-gap)
      } else {
        occupied.push((b.lo - edge-clearance, b.hi + edge-clearance))
        cands.push(b.lo - edge-clearance)
        cands.push(b.hi + edge-clearance)
      }
    }
    let clear = cx => occupied.all(iv => cx <= iv.at(0) or cx >= iv.at(1))
    let ok = cx => {
      if not clear(cx) { return false }
      if not side-exit { return true }
      if (
        cx > ux - uw / 2 - edge-clearance and cx < ux + uw / 2 + edge-clearance
      ) {
        return false
      }
      let vx2 = if cx < ux { ux - uw / 2 } else { ux + uw / 2 }
      order-in-rank
        .at(ur)
        .filter(a => a != ui)
        .all(a => (
          x.at(str(a)) + hw(a) <= calc.min(vx2, cx)
            or x.at(str(a)) - hw(a) >= calc.max(vx2, cx)
        ))
    }
    cands
      .filter(ok)
      // Prefer the source's own column (straight drop); break ties toward the
      // target. A several-feed unanchored source flips this: its column is
      // adrift, so stay near the target instead.
      .sorted(key: c => if prefer-target {
        (calc.abs(c - vx), calc.abs(ux - c))
      } else {
        (calc.abs(ux - c), calc.abs(c - vx))
      })
      .at(0, default: none)
  }

  // A long edge's route under the current widths: the corridor x, whether a decision
  // takes a side exit, and where it enters the target's top. The entry sits on the
  // corridor (a straight drop) unless that would crowd the target's direct inputs, in
  // which case it steps just outside them.
  let route-long = (from, to, x, w, ch) => {
    let side = shapeof.at(str(from)) == "diamond"
    let pt = lcount.at(str(from), default: 0) >= 2
    let cx = if side { corridor(from, to, true, pt, x, w, ch) } else { none }
    let side-ok = cx != none
    if not side-ok { cx = corridor(from, to, false, pt, x, w, ch) }
    // No candidate at all should be unreachable, but never crash on it:
    // degrade to a drop at the target's own column and let the shape-aware
    // attach land the arrow.
    if cx == none {
      cx = x.at(str(to))
      side-ok = false
    }
    let din-xs = din.at(str(to), default: ()).map(s => x.at(str(s)))
    let entry = cx
    if din-xs.len() > 0 {
      let dmin = calc.min(..din-xs)
      let dmax = calc.max(..din-xs)
      if entry > dmin - node-gap and entry < dmax + node-gap {
        entry = if entry <= x.at(str(to)) { dmin - node-gap } else {
          dmax + node-gap
        }
      }
    }
    (cx: cx, side-ok: side-ok, entry: entry)
  }

  // Widths may grow: relax, then widen each node to span its merging direct inputs
  // and to reach every long edge's entry column, and re-relax so the wider node
  // still fits. Widths depend on positions and positions on widths, so iterate to
  // the fixed point: stop once no width moves more than `weps`. Convergence is
  // geometric — relax's forward/backward averaging roughly halves the residual
  // each round — so the bound covers log2(extent / weps) plus slack for a
  // widening to cascade down the ranks; the loop breaks well before it on
  // ordinary diagrams.
  let weps = 0.005 // width change below this (canvas units) counts as settled
  let aeps = 0.02 // an unanchored node within this of its corridor is aligned
  let w = wof
  let x = relax(w, (:), (:))
  // The settle loop's final alignment targets, kept for the channel-iteration
  // re-relax below (an unanchored node must not lose its corridor alignment).
  let cwant-last = (:)
  let settled = false
  // The last round's full routes: the seat pass below must see the same
  // corridors the widths settled against — recomputing them afterwards against
  // the settled (wider) extents drifts the outside-lane candidates outward and
  // bends drops the loop had already straightened.
  let lastr = (:)
  // Inputs the absolute reach cap has permanently dropped, per node (see the
  // sticky-exclusion note in the widen pass).
  let excl = (:)
  for round in range(calc.max(16, ranks + 12)) {
    let ent = (:)
    lastr = (:)
    for c in cells {
      for it in lin.at(str(c.index), default: ()) {
        let r = route-long(it.from, c.index, x, w, (:))
        lastr.insert(str(it.ei), r)
        ent.insert(str(it.ei), r.entry)
      }
    }
    // An unanchored node (absent from every direct edge) with exactly ONE long
    // edge wants that edge's corridor column — recomputed each round, since
    // corridors shift as widths settle. Strictly one: with several long edges
    // the node would sit between its targets, and the targets' widen-to-entry
    // rule then chases a column between them — each widening pushes the pair
    // apart and moves the goal, which never converges. A several-edged feed
    // instead relies on the ordering fallback (layout.typ) to sit among its
    // consumers, and its edges jog as usual.
    let cw = (:)
    for (ei, e) in edges.enumerate() {
      if e.kind == "long" {
        let unf = str(e.from) not in nbr
        let unt = str(e.to) not in nbr
        if unf or unt {
          let cx = route-long(e.from, e.to, x, w, (:)).cx
          if unf {
            cw.insert(str(e.from), cw.at(str(e.from), default: ()) + (cx,))
          }
          if unt {
            cw.insert(str(e.to), cw.at(str(e.to), default: ()) + (cx,))
          }
        }
      }
    }
    let cwant = (:)
    for (k, v) in cw {
      if v.len() == 1 { cwant.insert(k, v.at(0)) }
    }
    cwant-last = cwant
    // Alignment joins the settle test: exiting while a node is still mid-chase
    // would freeze it short of its corridor.
    let stable = cwant.pairs().all(((k, v)) => calc.abs(x.at(k) - v) <= aeps)
    for c in cells {
      let key = str(c.index)
      // An input living in a box that excludes this node at its own rank must
      // bend into a seat, never widen the node: stretching toward it would
      // push the face into (or across) that box's band, which the push-out
      // sweep would then have to undo — for a merge of two sibling boxes'
      // outputs, unresolvably.
      let d = din.at(key, default: ()).filter(s => not boxed-off(c.index, s))
      let l = lin
        .at(key, default: ())
        .filter(it => not boxed-off(c.index, it.from))
      let cxn = x.at(key)
      // A lone direct input fans in without widening; two or more merge, so the node
      // grows to span them; a long input pulls the node out to its entry. Both only
      // up to `max-reach`: widths are symmetric about the node's centre, so spanning
      // an input the packing has pushed far off-centre doubles into a page-wide
      // face. A further input must not inflate the node — its edge bends into an
      // allocated seat instead (see the route pass below).
      let cand = (
        if d.len() >= 2 {
          d.map(s => (k: "d" + str(s), e: x.at(str(s))))
        } else { () }
      )
      let cand = (
        cand
          + l.map(it => (
            k: "l" + str(it.ei),
            e: ent.at(
              str(it.ei),
            ),
          ))
      )
      // The absolute cap is *sticky*: an input it drops stays dropped. Settle
      // wobble otherwise flips borderline inputs in and out of the included
      // set, and the width limit-cycles instead of converging. The set only
      // shrinks, so exclusions are finite and the loop contracts in between.
      let ex = excl.at(key, default: (:))
      let inc = cand.filter(i => i.k not in ex)
      for i in inc {
        if calc.abs(i.e - cxn) > max-reach { ex.insert(i.k, true) }
      }
      excl.insert(key, ex)
      let xs = inc.filter(i => i.k not in ex).map(i => i.e)
      // Everything excluded: revert to the measured width (an earlier round may
      // have left a stale wider value).
      if xs.len() == 0 {
        if cand.len() > 0 {
          let nw = wof.at(key)
          if calc.abs(nw - w.at(key)) > weps { stable = false }
          w.insert(key, nw)
        }
        continue
      }
      let lo = calc.min(cxn, ..xs)
      let hi = calc.max(cxn, ..xs)
      // Widths are symmetric about the centre, so reaching an input the packing
      // has pushed off-centre costs double. Cap the imbalance: one side may
      // out-reach the other by at most `widen-skew` — a node that can't sit
      // near the middle of its inputs stays label-sized and the arrows bend to
      // seats on it instead (see the route pass).
      let lr = cxn - lo
      let rr = hi - cxn
      let reach = calc.min(
        calc.max(lr, rr),
        calc.min(lr, rr) + widen-skew,
        max-reach,
      )
      let nw = calc.max(wof.at(str(c.index)), 2 * reach + 2 * pad-x)
      if calc.abs(nw - w.at(str(c.index))) > weps { stable = false }
      w.insert(str(c.index), nw)
    }
    // On a stable round nothing moved beyond `weps` (and every unanchored node
    // sits on its corridor), so the current positions are the relaxation of the
    // final widths — consistent, stop here.
    if stable {
      settled = true
      break
    }
    x = relax(w, cwant, (:))
  }

  // Push-out: within a rank, ordering keeps a group's members contiguous and
  // the border-scaled separations hold rank-mates clear — but a group's box is
  // as wide as its widest rank, so a node in a rank where the group is narrow
  // (or absent) can still sit inside the band. Each such node escapes to the
  // nearest clear ground. The bands it must clear are *merged* first: sibling
  // boxes can abut, and escaping one band only to land in the next (and be
  // bounced back, forever) is exactly how a node got stranded inside a box —
  // against the merged interval the nearer edge is chosen once. Borders keep
  // `group-pad` of air outside (members sit a pad inside, so the line runs
  // centred in a clear channel); rank-mates that escaped first are stepped
  // past at `node-gap`. Best-effort: two passes, then whatever remains stays
  // (a box edge through a pathological nest beats refusing the diagram).
  // `refine` bundles the two passes so the channel iteration below can rerun
  // them against reserved-channel geometry. Returns the adjusted positions
  // and whether anything moved.
  let refine = (x0, ch) => {
    let x = x0
    let moved = false
    // Sibling boxes keep daylight between their borders. Rank packing spaces
    // same-rank pairs, but a box edge is a multi-rank maximum (plus any
    // title-width growth), so two side-by-side boxes can end up touching
    // even though every row is properly spaced. Where two unrelated groups
    // share a rank and their bands close within `group-pad`, everything
    // right of the midpoint shifts right by the deficit — a rigid shear that
    // opens the gap without disturbing either side's internal layout.
    for pass in range(if live-groups.len() > 1 { 2 } else { 0 }) {
      for i in range(live-groups.len()) {
        for j in range(i + 1, live-groups.len()) {
          let (ga, gb2) = (live-groups.at(i), live-groups.at(j))
          // Skip ancestor/descendant pairs (one contains the other) and pairs
          // whose rank spans don't overlap (stacked boxes may share columns).
          let related = (
            ga.nodes.all(a => gp.at(str(a), default: ()).contains(gb2.id))
              or gb2.nodes.all(a => gp.at(str(a), default: ()).contains(ga.id))
          )
          let (sa, sb) = (gspan.at(ga.id), gspan.at(gb2.id))
          if related or sa.at(1) < sb.at(0) or sb.at(1) < sa.at(0) {
            continue
          }
          let ba = gband(ga, x, w, ch)
          let bb = gband(gb2, x, w, ch)
          let (left, right) = if ba.lo <= bb.lo { (ba, bb) } else { (bb, ba) }
          let deficit = group-pad - (right.lo - left.hi)
          if deficit > 0.001 {
            let mid = (left.hi + right.lo) / 2
            for c in cells {
              if x.at(str(c.index)) > mid {
                x.insert(str(c.index), x.at(str(c.index)) + deficit)
              }
            }
            moved = true
          }
        }
      }
    }
    // Push-out (see the block comment above): non-members escape the merged
    // group bands to the nearest clear ground.
    for pass in range(if live-groups.len() > 0 { 2 } else { 0 }) {
      let bands = live-groups.map(g => {
        let rs = g.nodes.map(a => rankof.at(str(a)))
        let b = gband(g, x, w, ch)
        (
          id: g.id,
          gt: calc.min(..rs),
          gb: calc.max(..rs),
          f0: b.lo - group-pad,
          f1: b.hi + group-pad,
        )
      })
      let half = a => w.at(str(a)) / 2 + mof.at(str(a))
      for r in range(ranks) {
        let esc = () // landings already escaped to in this rank: (c, h)
        for a in order-in-rank.at(r) {
          let mine = bands
            .filter(b => (
              r >= b.gt
                and r <= b.gb
                and not gp.at(str(a), default: ()).contains(b.id)
            ))
            .map(b => (b.f0, b.f1))
            .sorted(key: b => b.at(0))
          if mine.len() == 0 { continue }
          // Bands whose clear gap is too narrow for this node merge into one
          // obstacle — a slot it can't occupy is no escape target (this also
          // absorbs float error where two abutting bands miss by an epsilon).
          let ha = half(a)
          let merged = ()
          for v in mine {
            if merged.len() > 0 and v.at(0) <= merged.last().at(1) + 2 * ha {
              let m = merged.pop()
              merged.push((m.at(0), calc.max(m.at(1), v.at(1))))
            } else { merged.push(v) }
          }
          for m in merged {
            if x.at(str(a)) + ha > m.at(0) and x.at(str(a)) - ha < m.at(1) {
              let dl = x.at(str(a)) - (m.at(0) - ha)
              let dr = (m.at(1) + ha) - x.at(str(a))
              let dir = if dl <= dr { -1 } else { 1 }
              let c = if dir < 0 { m.at(0) - ha } else { m.at(1) + ha }
              // Step past already-escaped rank-mates. The collision test
              // leaves an epsilon of tolerance: a landing computed as exactly
              // the separation can round a hair short and re-collide with
              // itself forever. Bounded as a belt — progress is monotone, so
              // the cap never binds on real input.
              let bumped = true
              let tries = 0
              while bumped and tries < 32 {
                bumped = false
                tries += 1
                for p in esc {
                  if calc.abs(c - p.c) < ha + p.h + node-gap - 0.001 {
                    c = p.c + dir * (p.h + ha + node-gap)
                    bumped = true
                  }
                }
              }
              x.insert(str(a), c)
              esc.push((c: c, h: ha))
              moved = true
              break
            }
          }
        }
      }
    }
    (x: x, moved: moved)
  }
  let reroute = (x, ch) => {
    let lr = (:)
    for c in cells {
      for it in lin.at(str(c.index), default: ()) {
        lr.insert(str(it.ei), route-long(it.from, c.index, x, w, ch))
      }
    }
    lr
  }
  let rf = refine(x, (:))
  x = rf.x
  // A shear or escape can stretch a box — corridors chosen against the
  // pre-move geometry may then land inside a border, so reroute.
  if rf.moved { lastr = reroute(x, (:)) }

  // Segmented corridors: a long edge whose endpoints share a box must not
  // route outside it — but its straight corridor can be forced out when no
  // single column threads every crossed rank inside the band. Such an edge
  // re-routes rank by rank (a staircase): each crossed rank picks a clear
  // in-band column — an interior gap, a row edge, an endpoint column, or an
  // inside-border *channel* — minimising total sideways travel. A channel
  // column books a lane inside that border; if any were booked, the box
  // widens by the reserved lanes (`chan`), positions re-relax once against
  // the wider borders, and the routes are recomputed — one bounded iteration.
  let chan = (:)
  let seg-pass = (x, lr, ch) => {
    let segd = (:)
    let resv = (:)
    // Lane counters per box side: the k-th edge to book a side's channel gets
    // its own column, one lane further in — two edges sharing a side must
    // never draw on the same line.
    let ck = (:)
    let hwof = a => w.at(str(a)) / 2 + mof.at(str(a))
    for (ei, e) in edges.enumerate() {
      if e.kind != "long" { continue }
      let S = shared-box(e.from, e.to)
      if S == none or S not in live-by-id { continue }
      let band = gband(live-by-id.at(S), x, w, ch)
      let r0 = lr.at(str(ei))
      if r0.cx >= band.lo + 0.01 and r0.cx <= band.hi - 0.01 { continue }
      let ur = rankof.at(str(e.from))
      let vr = rankof.at(str(e.to))
      let span = range(calc.min(ur, vr) + 1, calc.max(ur, vr))
      if span.len() == 0 { continue }
      let ux = x.at(str(e.from))
      let vx = x.at(str(e.to))
      let chans = (
        band.lo + group-pad / 2 + ck.at(S + "|l", default: 0) * lane-gap,
        band.hi - group-pad / 2 - ck.at(S + "|r", default: 0) * lane-gap,
      )
      let states = span.map(r => {
        let row = order-in-rank.at(r)
        let occ = row.map(a => (
          x.at(str(a)) - hwof(a) - edge-clearance,
          x.at(str(a)) + hwof(a) + edge-clearance,
        ))
        // Other boxes keep their rules: a box with neither endpoint bans its
        // whole band at this rank, one with an endpoint only its border lines.
        for g in live-groups {
          if g.id == S { continue }
          let sp2 = gspan.at(g.id)
          if r < sp2.at(0) or r > sp2.at(1) { continue }
          let b = gband(g, x, w, ch)
          if (
            gp.at(str(e.from), default: ()).contains(g.id)
              or gp.at(str(e.to), default: ()).contains(g.id)
          ) {
            occ.push((b.lo - lane-gap / 2, b.lo + lane-gap / 2))
            occ.push((b.hi - lane-gap / 2, b.hi + lane-gap / 2))
          } else {
            occ.push((b.lo - edge-clearance, b.hi + edge-clearance))
          }
        }
        let clear = c => occ.all(iv => c <= iv.at(0) or c >= iv.at(1))
        let cands = (ux, vx)
        for i in range(calc.max(row.len() - 1, 0)) {
          let lo2 = x.at(str(row.at(i))) + hwof(row.at(i))
          let hi2 = x.at(str(row.at(i + 1))) - hwof(row.at(i + 1))
          if hi2 - lo2 >= 2 * edge-clearance { cands.push((lo2 + hi2) / 2) }
        }
        if row.len() > 0 {
          cands.push(
            calc.min(..row.map(a => x.at(str(a)) - hwof(a))) - edge-clearance,
          )
          cands.push(
            calc.max(..row.map(a => x.at(str(a)) + hwof(a))) + edge-clearance,
          )
        }
        (
          cands.filter(c => (
            c >= band.lo + 0.01 and c <= band.hi - 0.01 and clear(c)
          ))
            + chans
        )
      })
      // Shortest total sideways travel ux -> columns -> vx (tiny DP).
      let cost = states.at(0).map(c => calc.abs(c - ux))
      let back = ()
      for ri in range(1, states.len()) {
        let prev = states.at(ri - 1)
        let nc = ()
        let bk = ()
        for c in states.at(ri) {
          let best = 0
          let bv = cost.at(0) + calc.abs(c - prev.at(0))
          for (k, p) in prev.enumerate() {
            let v = cost.at(k) + calc.abs(c - p)
            if v < bv - 0.0001 {
              bv = v
              best = k
            }
          }
          nc.push(bv)
          bk.push(best)
        }
        cost = nc
        back.push(bk)
      }
      let besti = 0
      let bestv = cost.at(0) + calc.abs(states.last().at(0) - vx)
      for (k, c) in states.last().enumerate() {
        let v = cost.at(k) + calc.abs(c - vx)
        if v < bestv - 0.0001 {
          bestv = v
          besti = k
        }
      }
      let idxs = (besti,)
      for ri in range(back.len() - 1, -1, step: -1) {
        idxs.insert(0, back.at(ri).at(idxs.first()))
      }
      let cols = idxs.enumerate().map(((ri, k)) => states.at(ri).at(k))
      let used-l = cols.any(c => calc.abs(c - chans.at(0)) < 0.001)
      let used-r = cols.any(c => calc.abs(c - chans.at(1)) < 0.001)
      if used-l or used-r {
        let cur = resv.at(S, default: (l: 0, r: 0))
        resv.insert(S, (
          l: cur.l + if used-l { 1 } else { 0 },
          r: cur.r + if used-r { 1 } else { 0 },
        ))
        if used-l { ck.insert(S + "|l", ck.at(S + "|l", default: 0) + 1) }
        if used-r { ck.insert(S + "|r", ck.at(S + "|r", default: 0) + 1) }
      }
      // Entry steps off the target's direct-input columns, as route-long does.
      let din-xs = din.at(str(e.to), default: ()).map(s2 => x.at(str(s2)))
      let entry = cols.last()
      if din-xs.len() > 0 {
        let dmin = calc.min(..din-xs)
        let dmax = calc.max(..din-xs)
        if entry > dmin - node-gap and entry < dmax + node-gap {
          entry = if entry <= x.at(str(e.to)) { dmin - node-gap } else {
            dmax + node-gap
          }
        }
      }
      segd.insert(str(ei), (cols: cols, entry: entry))
    }
    (seg: segd, resv: resv)
  }
  let sp = seg-pass(x, lastr, (:))
  if sp.resv.len() > 0 {
    chan = sp.resv
    x = relax(w, cwant-last, chan)
    let rf2 = refine(x, chan)
    x = rf2.x
    lastr = reroute(x, chan)
    sp = seg-pass(x, lastr, chan)
  }
  for (ei, s) in sp.seg {
    lastr.insert(ei, (
      ..lastr.at(ei),
      cx: s.cols.first(),
      side-ok: false,
      entry: s.entry,
      cols: s.cols,
      last: s.cols.last(),
    ))
  }

  // How many *direct* children each node fans out to. A node with one direct child
  // drops that edge straight down; a genuine fork spreads toward each target. Long
  // and back edges route on the side, so they don't count as fan-out.
  let fanout = (:)
  for e in edges {
    if e.kind == "direct" {
      fanout.insert(str(e.from), fanout.at(str(e.from), default: 0) + 1)
    }
  }

  // Exit allocation — the mirror of the entry seats. A node with several
  // bottom-leaving edges gives each its own exit column on its flow face:
  // otherwise a lone direct edge and every long edge depart at the node's
  // centre (and spread exits saturate at the same flank for two far same-side
  // targets), drawing several edges as one line until they diverge. Natural
  // exits aim at each edge's outgoing direction; where they crowd, a
  // forward/backward min-pitch pass separates them in direction order, so
  // edges never cross at the node. Single-exit nodes keep today's behaviour.
  let dexit = (:)
  for c in cells {
    let key = str(c.index)
    let outs = ()
    for (ei, e) in edges.enumerate() {
      if str(e.from) != key { continue }
      if e.kind == "direct" {
        outs.push((kind: "d", key: key + ">" + str(e.to), aim: x.at(str(e.to))))
      } else if e.kind == "long" {
        let r = lastr.at(str(ei))
        if not r.side-ok {
          outs.push((
            kind: "l",
            ei: ei,
            aim: r.at("cols", default: (r.cx,)).first(),
          ))
        }
      }
    }
    if outs.len() < 2 { continue }
    let sx = x.at(key)
    let sw = w.at(key)
    let inset = calc.min(pad-x, sw / 4)
    let (lo, hi) = (sx - sw / 2 + inset, sx + sw / 2 - inset)
    let half = 0.7 * sw / 2
    let ordered = outs.sorted(key: o => o.aim)
    let n = ordered.len()
    let pitch = calc.min(node-gap / 2, (hi - lo) / (n + 1))
    // Natural spread exits, then enforce the pitch left-to-right and cap the
    // overflow back from the right face edge — order preserved, every pair
    // at least a pitch apart, all on the face.
    let exs = ordered.map(o => (
      calc.max(lo, calc.min(
        hi,
        sx + calc.max(calc.min(o.aim - sx, half), -half),
      ))
    ))
    for i in range(1, n) {
      exs.at(i) = calc.max(exs.at(i), exs.at(i - 1) + pitch)
    }
    for i in range(n - 1, -1, step: -1) {
      exs.at(i) = calc.min(exs.at(i), hi - (n - 1 - i) * pitch)
    }
    for (i, o) in ordered.enumerate() {
      if o.kind == "d" { dexit.insert(o.key, exs.at(i)) } else {
        lastr.insert(str(o.ei), (..lastr.at(str(o.ei)), exit: exs.at(i)))
      }
    }
  }

  // Per-target seat and route bookkeeping the per-edge router can't do. Direct
  // parents on the face own their columns; a direct parent the widen caps left
  // outside the face gets a *seat* allocated inward from its side's face edge
  // (returned in `dseat` for the renderer to aim at). Long edges follow: a
  // corridor that lands on the face with room of its own keeps its straight
  // drop, any other jogs into the next free seat, spaced `node-gap` from every
  // occupant. Phase 1 is x-only; the vertical gap each target's bent tails fan
  // through is sized to their number afterwards.
  // A closure would capture the occupancy list by value and never see later
  // pushes, so the check takes it explicitly.
  let free = (sx, tk) => tk.all(t => calc.abs(sx - t) >= node-gap / 2)
  let allocs = ()
  for c in cells {
    let d = din.at(str(c.index), default: ())
    let ins = lin.at(str(c.index), default: ())
    if d.len() == 0 and ins.len() == 0 { continue }
    let tx = x.at(str(c.index))
    let tw = w.at(str(c.index))
    // `pad-x` keeps seats off the corners of a wide face — but a cross-narrow
    // node (any plain box in a horizontal flow, whose cross extent is its
    // measured height) can be barely wider than two pads, collapsing the face
    // to a point and piling every arrow onto it. Capping the inset at a
    // quarter of the extent keeps at least half of every face seatable; the
    // allocate/repair machinery below then spaces landings within it.
    let inset = calc.min(pad-x, tw / 4)
    let face-lo = tx - tw / 2 + inset
    let face-hi = tx + tw / 2 - inset
    // Each direct parent's *projected landing*: the renderer aims a parent's
    // entry at its spread exit (toward the target when the parent forks), not
    // at the parent's own column — modelling the column here let two forking
    // parents clamp onto the same face edge and double up their arrows. A
    // projection outside the face bends into an allocated seat like any other
    // far input.
    let px = d.map(s => {
      let sx = x.at(str(s))
      // A parent's arrow lands where its exit column meets this face: the
      // allocated exit when the source has several departures, else the
      // spread aim (the 0.7 matches render's `attach(s, .., 0.7)` — keep the
      // two in step, render.typ direct-edge branch).
      let land = dexit.at(str(s) + ">" + str(c.index), default: {
        let aim = if fanout.at(str(s), default: 0) == 1 { sx } else { tx }
        let half = 0.7 * w.at(str(s)) / 2
        sx + calc.max(calc.min(aim - sx, half), -half)
      })
      (s: s, x: land)
    })
    let taken = px.filter(p => p.x >= face-lo and p.x <= face-hi).map(p => p.x)
    let allocate = (cx, tk) => {
      let side = if cx <= tx { -1 } else { 1 }
      let s = if side < 0 { face-lo } else { face-hi }
      let steps = 0
      while not free(s, tk) and steps < 32 {
        s = s - side * node-gap
        steps += 1
      }
      calc.max(face-lo, calc.min(face-hi, s))
    }
    // Everything that must *bend* into the face shares one allocation: parents
    // the skew cap left off the face, and long edges whose corridor can't take
    // a free straight drop. Long edges use the settle loop's own routes (see
    // `lastr`), not a recomputation. Seated straight drops claim their columns
    // as they come.
    let seated-longs = ()
    let benders = ()
    for p in px.filter(p => p.x < face-lo or p.x > face-hi) {
      benders.push((kind: "direct", key: str(p.s), cx: p.x))
    }
    // A segmented route approaches on its *last* column; a straight one on
    // its single corridor column (last == cx there).
    for e in ins
      .map(it => (it: it, r: lastr.at(str(it.ei))))
      .sorted(key: e => -calc.abs(e.r.at("last", default: e.r.cx) - tx)) {
      let rcx = e.r.at("last", default: e.r.cx)
      let seated = rcx >= face-lo and rcx <= face-hi and free(rcx, taken)
      if seated {
        taken.push(rcx)
        seated-longs.push((ei: e.it.ei, r: e.r))
      } else {
        benders.push((kind: "long", ei: e.it.ei, r: e.r, cx: rcx))
      }
    }
    // The straight landings — on-face parents and seated drops — are fixed;
    // bender seats must never coincide with them or with each other.
    let fixed = taken
    // Farthest source first, so it claims the outermost seat on its side.
    let ordered = benders.sorted(key: b => -calc.abs(b.cx - tx))
    let seated-benders = ()
    for b in ordered {
      let seat = allocate(b.cx, taken)
      taken.push(seat)
      seated-benders.push((..b, seat: seat))
    }
    // Capacity repair: when the face ran out of gap-spaced slots (the search
    // clamps and can land on an occupied column), respace the bender seats —
    // evenly across the face in their left-to-right order, nudged off every
    // fixed column, each strictly right of the last. Pitch may compress at
    // absurd fan-in, but every landing on the face stays distinct.
    let crowded = range(taken.len()).any(i => (
      range(i + 1, taken.len()).any(j => (
        calc.abs(taken.at(i) - taken.at(j)) < node-gap / 2 - 0.001
      ))
    ))
    if crowded and seated-benders.len() > 0 {
      let bysx = seated-benders.sorted(key: b => b.seat)
      let k = bysx.len()
      let pitch = calc.min(
        node-gap / 2,
        (face-hi - face-lo) / (k + fixed.len() + 1),
      )
      let repaired = ()
      let prev = face-lo - pitch
      for (i, b) in bysx.enumerate() {
        let s = calc.max(
          face-lo + (face-hi - face-lo) * (i + 1) / (k + 1),
          prev + pitch,
        )
        let tries = 0
        while tries < 8 and fixed.any(fc => calc.abs(s - fc) < pitch) {
          s = s + pitch
          tries += 1
        }
        s = calc.max(s, prev + 0.02)
        prev = s
        repaired.push((..b, seat: s))
      }
      seated-benders = repaired
    }
    allocs.push((
      key: str(c.index),
      rank: c.rank,
      tx: tx,
      seated: seated-longs,
      benders: seated-benders,
    ))
  }

  // Vertical space adapts to traffic: the gap above a rank grows to hold the
  // largest fan of bent tails arriving there (at `lane-gap` pitch, entered by
  // at least a `stub`-length final drop), instead of squeezing them into a
  // fixed fraction of `rank-gap`.
  let traffic = range(ranks).map(_ => 0)
  for a in allocs {
    for side in (-1, 1) {
      let n = a
        .benders
        .filter(b => if side < 0 { b.cx <= a.tx } else { b.cx > a.tx })
        .len()
      traffic.at(a.rank) = calc.max(traffic.at(a.rank), n)
    }
  }
  // Exit fans need room too: a node's several long departures fan at
  // lane-gap pitch in the gap beneath its rank (see the hy fan below).
  let exit-fan = (:)
  for (ei, e) in edges.enumerate() {
    if (
      e.kind == "long" and str(ei) in lastr and not lastr.at(str(ei)).side-ok
    ) {
      exit-fan.insert(str(e.from), exit-fan.at(str(e.from), default: 0) + 1)
    }
  }
  for (k, n) in exit-fan {
    let below = rankof.at(k) + 1
    if n >= 2 and below < ranks {
      traffic.at(below) = calc.max(traffic.at(below), n)
    }
  }
  let gaps = range(ranks).map(r => if r == 0 { 0 } else {
    calc.max(rank-gap, 2 * (stub + traffic.at(r) * lane-gap))
  })
  // Group borders need vertical room too: the gap above a box's top rank
  // holds its title band and padding, the gap below its bottom rank its
  // padding. Nested boxes opening (or closing) at the same rank each add
  // their own, so their borders stack instead of coinciding. A box whose top
  // rank is the first extends the canvas upward instead.
  for g in live-groups {
    let rs = g.nodes.map(a => rankof.at(str(a)))
    let (gt, gb) = (calc.min(..rs), calc.max(..rs))
    if gt > 0 { gaps.at(gt) += title-room + group-pad }
    if gb + 1 < ranks { gaps.at(gb + 1) += group-pad }
  }
  let rank-y = (0,)
  for r in range(1, ranks) {
    rank-y.push(
      rank-y.at(r - 1) - (rank-h.at(r - 1) / 2 + gaps.at(r) + rank-h.at(r) / 2),
    )
  }
  let y = (:)
  for c in cells { y.insert(str(c.index), rank-y.at(c.rank)) }

  // Group hulls: each box wraps its member nodes and child boxes with
  // `group-pad` of breathing room and a `title-room` band along its top.
  // Members are declared before their group, so a child's hull always exists
  // when the parent wraps it — the parent's border sits a pad outside the
  // child's, and their title bands stack.
  let hulls = (:)
  for g in groups {
    let xs0 = g.nodes.map(a => x.at(str(a)) - w.at(str(a)) / 2)
    let xs1 = g.nodes.map(a => (
      x.at(str(a)) + w.at(str(a)) / 2 + loop-room(a)
    ))
    let ys0 = g.nodes.map(a => y.at(str(a)) - hof.at(str(a)) / 2)
    let ys1 = g.nodes.map(a => y.at(str(a)) + hof.at(str(a)) / 2)
    for m in g.members {
      if m in hulls {
        let h = hulls.at(m)
        xs0.push(h.x0)
        xs1.push(h.x1)
        ys0.push(h.y0)
        ys1.push(h.y1)
      }
    }
    if xs0.len() == 0 { continue }
    // Reserved routing channels widen the box, exactly as in `gband`.
    let cc = chan.at(g.id, default: (l: 0, r: 0))
    let x0 = calc.min(..xs0) - group-pad - cc.l * lane-gap
    let x1 = calc.max(..xs1) + group-pad + cc.r * lane-gap
    // A box is never narrower than its title (plus breathing room): a long
    // name on a small group widens the box instead of overflowing it.
    let want = g.at("tw", default: 0) + group-pad
    if x1 - x0 < want {
      let c = (x0 + x1) / 2
      x0 = c - want / 2
      x1 = c + want / 2
    }
    hulls.insert(g.id, (
      x0: x0,
      x1: x1,
      y0: calc.min(..ys0) - group-pad,
      y1: calc.max(..ys1) + group-pad + title-room,
      depth: g.depth,
    ))
  }

  // Heights: a seated drop keeps its label run at the gap's midpoint; bent
  // tails fan at fixed pitch — farthest lowest, so nested tails and the
  // corridors that terminate on them never cross.
  let route = (:)
  let dseat = (:)
  for a in allocs {
    let top = y.at(a.key) + hof.at(a.key) / 2
    for s in a.seated {
      route.insert(str(s.ei), (
        ..s.r,
        entry: s.r.at("last", default: s.r.cx),
        ay: top + gaps.at(a.rank) / 2,
      ))
    }
    for side in (-1, 1) {
      let group = a
        .benders
        .filter(b => if side < 0 { b.cx <= a.tx } else { b.cx > a.tx })
        .sorted(key: b => -calc.abs(b.cx - a.tx))
      for (i, b) in group.enumerate() {
        let ay = top + stub + i * lane-gap
        if b.kind == "direct" {
          // Keyed by (from, to): a direct edge is unique per pair here.
          dseat.insert(b.key + ">" + a.key, (x: b.seat, ay: ay))
        } else {
          route.insert(str(b.ei), (..b.r, entry: b.seat, ay: ay))
        }
      }
    }
  }
  // Every long edge also carries its head clearance: the y its corridor may
  // drop to below the source before jogging across — half-way into the gap
  // beneath the source's rank, or, when a node has several long departures,
  // its own height in a fan below the node (farthest corridor jogging first,
  // like the entry tails) so their horizontal runs never overlie.
  let exit-rank = (:)
  for (ei, e) in edges.enumerate() {
    if e.kind == "long" and str(ei) in route and not route.at(str(ei)).side-ok {
      let r = route.at(str(ei))
      let ex = r.at("exit", default: x.at(str(e.from)))
      exit-rank.insert(
        str(e.from),
        exit-rank.at(str(e.from), default: ())
          + ((ei: ei, dist: calc.abs(r.cx - ex)),),
      )
    }
  }
  let hy-of = (:)
  for (k, fans) in exit-rank {
    if fans.len() < 2 { continue }
    let bottom = y.at(k) - hof.at(k) / 2
    for (i, f) in fans.sorted(key: f => -f.dist).enumerate() {
      hy-of.insert(str(f.ei), bottom - stub - i * lane-gap)
    }
  }
  for (ei, e) in edges.enumerate() {
    if e.kind == "long" and str(ei) in route {
      let rs = rankof.at(str(e.from))
      // A long edge always descends, so its source is never the last rank and
      // `rs + 1` is in range; `default` degrades a mis-ranked edge to a plain
      // drop instead of crashing, rather than trusting that invariant blindly.
      let hy = hy-of.at(
        str(ei),
        default: (
          y.at(str(e.from))
            - hof.at(str(e.from)) / 2
            - gaps.at(rs + 1, default: rank-gap) / 2
        ),
      )
      route.insert(str(ei), (..route.at(str(ei)), hy: hy))
      // A segmented route changes column between ranks: each change becomes a
      // jog (y, next-column) halfway into the inter-rank gap — the renderer
      // draws down to y, across to the next column, and continues.
      let r = route.at(str(ei))
      if "cols" in r {
        let span = range(
          calc.min(rs, rankof.at(str(e.to))) + 1,
          calc.max(rs, rankof.at(str(e.to))),
        )
        let jogs = ()
        let prev = r.cols.first()
        for (i, rr) in span.enumerate() {
          if calc.abs(r.cols.at(i) - prev) > 0.001 {
            jogs.push((
              y: (
                rank-y.at(rr - 1)
                  - rank-h.at(rr - 1) / 2
                  - gaps.at(rr, default: rank-gap) / 2
              ),
              x: r.cols.at(i),
            ))
            prev = r.cols.at(i)
          }
        }
        route.insert(str(ei), (..r, jogs: jogs))
      }
    }
  }
  // Jogging corridors must not share a lane: where two overlap in x and in the
  // ranks they cross, shift the later one outward by `lane-gap` until clear.
  // Seated corridors never move — theirs is the straight drop being protected.
  let lanes = ()
  for (ei, e) in edges.enumerate() {
    if e.kind != "long" { continue }
    let r = route.at(str(ei))
    let span = (
      calc.min(rankof.at(str(e.from)), rankof.at(str(e.to))),
      calc.max(rankof.at(str(e.from)), rankof.at(str(e.to))),
    )
    // A segmented route was placed rank by rank against real clearances:
    // register its runs so other corridors keep off, but never shift it.
    if "cols" in r {
      for c in r.cols.dedup() { lanes.push((cx: c, span: span)) }
      continue
    }
    let seated = calc.abs(r.cx - r.entry) < 0.01
    if seated {
      lanes.push((cx: r.cx, span: span))
      continue
    }
    let tx = x.at(str(e.to))
    let side = if r.cx <= tx { -1 } else { 1 }
    let cx = r.cx
    let steps = 0
    while (
      steps < 32
        and lanes.any(l => (
          calc.abs(l.cx - cx) < lane-gap
            and l.span.at(0) < span.at(1)
            and span.at(0) < l.span.at(1)
        ))
    ) {
      cx = cx + side * lane-gap
      steps += 1
    }
    lanes.push((cx: cx, span: span))
    if cx != r.cx { route.insert(str(ei), (..r, cx: cx)) }
  }

  (
    x: x,
    y: y,
    w: w,
    route: route,
    dseat: dseat,
    dexit: dexit,
    fanout: fanout,
    hulls: hulls,
    settled: settled,
  )
}

// label-spots: collision-free anchors for edge labels. Pure — the renderer
// measures each label and hands over final-space geometry; this walks every
// labelled edge in order and picks the first spot that overlaps no node box,
// no label already placed, and no other edge's line — a label is drawn over
// every line with a knockout behind it, so a spot on a foreign line would
// erase that line. Its own line is exempt: sitting on it (and breaking it up)
// is the point.
//
// items: per labelled edge — `segs`: its segments as (ax, ay, bx, by) tuples,
//        already sorted by the caller's preference (longest vertical run first,
//        so an uncontested label sits exactly where it always has); `hw`/`hh`:
//        the label box's half-extents; `edge`: the edge the label belongs to
//        (its segments in `lines` don't count as obstacles); `tip`: the path's
//        final point — the arrow tip; `off`: an optional (x, y) author nudge
//        (canvas units) added to the final anchor and its reserved rectangle.
// boxes: node rectangles as (cx, cy, hw, hh).
// lines: every edge's segments as (edge: index, box: (cx, cy, hw, hh)) — the
//        segment's bounding box, degenerate in one axis (paths are orthogonal,
//        so that box is the segment, exactly).
// head-room: how close a label may come to its own arrow tip. The renderer
//        passes the stub token: the final approach run sized to keep the
//        arrowhead clear stays visible in full.
//
// The own-line exemption has limits — the knockout breaking a long run in the
// middle is the interrupted-line look, but a label must not blanket its line:
// a candidate keeps `visible` of its segment showing past both ends of the
// box (a segment too short for that offers no spots), and stays `head-room`
// off its own tip (a label on the arrowhead reads as a floating head).
//
// Candidates walk each segment at fractions of its length, midpoint first. When
// every candidate collides, constraints shed in order of harm: first line
// cleanliness goes (a knockout gap in a foreign line stays legible; a label
// under a label does not), then, last, the label falls back to the best
// segment's midpoint (a rare overlap beats a missing label).
#let label-spots(items, boxes, lines, head-room: none) = {
  assert(head-room != none, message: "label-spots: `head-room` is required")
  let margin = 0.06 // breathing room between a label and anything else
  let visible = 0.12 // line that must stay showing past each end of a label
  let hits = (a, b) => (
    calc.abs(a.at(0) - b.at(0)) < a.at(2) + b.at(2)
      and calc.abs(a.at(1) - b.at(1)) < a.at(3) + b.at(3)
  )
  let placed = ()
  let out = ()
  for it in items {
    let anchor = none
    let own = it.at("edge", default: none)
    let tip = it.at("tip", default: none)
    // An author's explicit shift (canvas units, page space). Applied to the
    // chosen anchor and to the rectangle later labels dodge — so a nudged
    // label still reserves its real footprint.
    let off = it.at("off", default: (0, 0))
    // A crowded diagram may leave no spot satisfying everything. Degrade in
    // order of harm: a second pass gives up line cleanliness (a knockout gap
    // in a foreign line is legible) before a label may ever cover another
    // label, a node, or its own arrowhead.
    for relaxed in (false, true) {
      if anchor != none { break }
      for s in it.segs {
        if anchor != none { break }
        // Length and the label's half-extent along the segment's axis
        // (segments are orthogonal, so one of the two terms is zero).
        let l = calc.abs(s.at(2) - s.at(0)) + calc.abs(s.at(3) - s.at(1))
        let ext = if (
          calc.abs(s.at(3) - s.at(1)) >= calc.abs(s.at(2) - s.at(0))
        ) {
          it.hh
        } else {
          it.hw
        }
        // Coarse spots first — established placements stay put — then a finer
        // ring, reached only when all five fail, so a label threads a narrow
        // clean band (between two crossing lines, say) before giving up.
        for f in (
          0.5,
          0.35,
          0.65,
          0.2,
          0.8,
          0.12,
          0.28,
          0.42,
          0.58,
          0.72,
          0.88,
        ) {
          if f * l < ext + visible or (1 - f) * l < ext + visible { continue }
          let px = s.at(0) + (s.at(2) - s.at(0)) * f
          let py = s.at(1) + (s.at(3) - s.at(1)) * f
          let r = (px, py, it.hw + margin, it.hh + margin)
          if (
            (tip == none or not hits(r, (..tip, head-room, head-room)))
              and placed.all(q => not hits(r, q))
              and boxes.all(q => not hits(r, q))
              and (
                relaxed or lines.all(q => q.edge == own or not hits(r, q.box))
              )
          ) {
            anchor = (px + off.at(0), py + off.at(1))
            placed.push((anchor.at(0), anchor.at(1), r.at(2), r.at(3)))
            break
          }
        }
      }
    }
    if anchor == none {
      let s = it.segs.at(0)
      anchor = (
        (s.at(0) + s.at(2)) / 2 + off.at(0),
        (s.at(1) + s.at(3)) / 2 + off.at(1),
      )
      placed.push((anchor.at(0), anchor.at(1), it.hw + margin, it.hh + margin))
    }
    out.push(anchor)
  }
  out
}
