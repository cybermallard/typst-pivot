// place: measured cells -> coordinates. Pure, no cetz — the geometric half of the
// flowchart pipeline. `layout` fixes each node's rank and order; `place` turns
// measured sizes into positions — relaxing each rank toward a straight spine,
// widening a merge target to seat its inputs, choosing each long edge's corridor —
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
// (direct children per node), and `settled`: whether the widen loop reached its
// fixed point within the bound. If it didn't, widths may under-span their inputs;
// the renderer's shape-aware attach still lands every edge on an outline.

#let place(
  cells,
  edges,
  ranks,
  node-gap: none,
  rank-gap: none,
  pad-x: none,
  back-margin: none,
) = {
  for (name, v) in (
    ("node-gap", node-gap),
    ("rank-gap", rank-gap),
    ("pad-x", pad-x),
    ("back-margin", back-margin),
  ) {
    assert(v != none, message: "place: `" + name + "` is required")
  }
  if cells.len() == 0 {
    return (x: (:), y: (:), w: (:), route: (:), fanout: (:), settled: true)
  }

  let wof = (:)
  let hof = (:)
  for c in cells {
    wof.insert(str(c.index), c.w)
    hof.insert(str(c.index), c.h)
  }

  // Nodes of each rank, in order; rank height is its tallest node.
  let order-in-rank = range(ranks).map(r => cells
    .filter(c => c.rank == r)
    .sorted(key: c => c.order)
    .map(c => c.index))
  let rank-h = order-in-rank.map(row => if row.len() > 0 {
    calc.max(..row.map(a => hof.at(str(a))))
  } else { 0 })
  let rank-y = (0,)
  for r in range(1, ranks) {
    rank-y.push(
      rank-y.at(r - 1) - (rank-h.at(r - 1) / 2 + rank-gap + rank-h.at(r) / 2),
    )
  }

  // Neighbours across ranks, from the *direct* edges only (long/back edges route on
  // the side and shouldn't tug nodes out of line).
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

  // Coordinate assignment: start centred by order, then relax each node toward the
  // median of its neighbours (aligning chains) while a forward and a backward pass
  // hold each rank's separation. Both preserve the minimum gap, so their average
  // does too — the spine straightens without nodes ever overlapping.
  let relax = widths => {
    let x = (:)
    for r in range(ranks) {
      let row = order-in-rank.at(r)
      let total = (
        row.map(a => widths.at(str(a))).sum(default: 0)
          + calc.max(row.len() - 1, 0) * node-gap
      )
      let cx = -total / 2
      for a in row {
        x.insert(str(a), cx + widths.at(str(a)) / 2)
        cx += widths.at(str(a)) + node-gap
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
          if ns.len() > 0 { median(ns.map(nn => x.at(str(nn)))) } else {
            x.at(str(a))
          }
        })
        let sep = i => (
          widths.at(str(row.at(i))) / 2
            + node-gap
            + widths.at(str(row.at(i + 1))) / 2
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
  let corridor = (ui, vi, side-exit, x, w) => {
    let ur = rankof.at(str(ui))
    let vr = rankof.at(str(vi))
    let ux = x.at(str(ui))
    let uw = w.at(str(ui))
    let vx = x.at(str(vi))
    let m = node-gap / 2
    let minx = calc.min(..cells.map(c => (
      x.at(str(c.index)) - w.at(str(c.index)) / 2
    )))
    let maxx = calc.max(..cells.map(c => (
      x.at(str(c.index)) + w.at(str(c.index)) / 2
    )))
    let occupied = ()
    let cands = (vx, minx - back-margin, maxx + back-margin)
    cands += if side-exit { (ux - uw / 2 - m, ux + uw / 2 + m) } else { (ux,) }
    for r in range(calc.min(ur, vr) + 1, calc.max(ur, vr)) {
      let row = order-in-rank.at(r)
      for a in row {
        occupied.push((
          x.at(str(a)) - w.at(str(a)) / 2 - m,
          x.at(str(a)) + w.at(str(a)) / 2 + m,
        ))
      }
      if row.len() > 0 {
        cands.push(
          calc.min(..row.map(a => x.at(str(a)) - w.at(str(a)) / 2)) - m,
        )
        cands.push(
          calc.max(..row.map(a => x.at(str(a)) + w.at(str(a)) / 2)) + m,
        )
      }
    }
    let clear = cx => occupied.all(iv => cx <= iv.at(0) or cx >= iv.at(1))
    let ok = cx => {
      if not clear(cx) { return false }
      if not side-exit { return true }
      if cx > ux - uw / 2 - m and cx < ux + uw / 2 + m { return false }
      let vx2 = if cx < ux { ux - uw / 2 } else { ux + uw / 2 }
      order-in-rank
        .at(ur)
        .filter(a => a != ui)
        .all(a => (
          x.at(str(a)) + w.at(str(a)) / 2 <= calc.min(vx2, cx)
            or x.at(str(a)) - w.at(str(a)) / 2 >= calc.max(vx2, cx)
        ))
    }
    cands
      .filter(ok)
      // Prefer the source's own column (straight drop); break ties toward the target.
      .sorted(key: c => (calc.abs(ux - c), calc.abs(c - vx)))
      .at(0, default: none)
  }

  // A long edge's route under the current widths: the corridor x, whether a decision
  // takes a side exit, and where it enters the target's top. The entry sits on the
  // corridor (a straight drop) unless that would crowd the target's direct inputs, in
  // which case it steps just outside them.
  let route-long = (from, to, x, w) => {
    let side = shapeof.at(str(from)) == "diamond"
    let cx = if side { corridor(from, to, true, x, w) } else { none }
    let side-ok = cx != none
    if not side-ok { cx = corridor(from, to, false, x, w) }
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
  let w = wof
  let x = relax(w)
  let settled = false
  for round in range(calc.max(16, ranks + 12)) {
    let ent = (:)
    for c in cells {
      for it in lin.at(str(c.index), default: ()) {
        ent.insert(str(it.ei), route-long(it.from, c.index, x, w).entry)
      }
    }
    let stable = true
    for c in cells {
      let d = din.at(str(c.index), default: ())
      let l = lin.at(str(c.index), default: ())
      let cxn = x.at(str(c.index))
      // A lone direct input fans in without widening; two or more merge, so the node
      // grows to span them. A long input always pulls the node out to its entry.
      let merge-xs = if d.len() >= 2 { d.map(s => x.at(str(s))) } else { () }
      let xs = merge-xs + l.map(it => ent.at(str(it.ei)))
      if xs.len() == 0 { continue }
      let lo = calc.min(cxn, ..xs)
      let hi = calc.max(cxn, ..xs)
      let reach = calc.max(cxn - lo, hi - cxn)
      let nw = calc.max(wof.at(str(c.index)), 2 * reach + 2 * pad-x)
      if calc.abs(nw - w.at(str(c.index))) > weps { stable = false }
      w.insert(str(c.index), nw)
    }
    // On a stable round nothing moved beyond `weps`, so the current positions are
    // (numerically) the relaxation of the final widths — consistent, stop here.
    if stable {
      settled = true
      break
    }
    x = relax(w)
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

  // Each long edge's route for drawing. The widen loop only needed `.entry` each
  // round; now that widths have settled, compute the full route once (corridor +
  // side-ok + entry) — a straight drop, stepped aside only to clear direct inputs.
  let route = (:)
  for c in cells {
    for it in lin.at(str(c.index), default: ()) {
      route.insert(str(it.ei), route-long(it.from, c.index, x, w))
    }
  }

  let y = (:)
  for c in cells { y.insert(str(c.index), rank-y.at(c.rank)) }

  (x: x, y: y, w: w, route: route, fanout: fanout, settled: settled)
}
