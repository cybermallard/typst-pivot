#import "@preview/cetz:0.5.2" as cetz
#import "../theme.typ" as theme-mod
#import "model.typ": model
#import "layout.typ": layout
#import "place.typ": place

// flowchart: nodes joined by directed edges, laid out in ranked layers. `layout`
// fixes each node's rank and order; `place` (pure) turns measured sizes into
// coordinates — a straight spine, merge targets widened to seat their inputs, a
// corridor per long edge. Here we measure the labels and draw: a direct (one-rank)
// edge runs straight into a single-input target or fans into a shared one; a long or
// back edge takes a side channel clear of the body. The engine works in a canonical
// vertical (top to bottom) flow; `orientation: "horizontal"` is the same picture
// transposed at the draw step. Node colour is opt-in (`fill:`). Returns content.
#let flowchart(
  ..items,
  orientation: "vertical",
  theme: theme-mod.default,
) = context {
  assert(
    orientation in ("vertical", "horizontal"),
    message: "flowchart: orientation must be \"vertical\" or \"horizontal\", got "
      + repr(orientation),
  )
  let g = layout(model(items.pos()))
  // An empty diagram has no nodes to place and no extent to measure — draw nothing.
  if g.cells.len() == 0 { return none }

  // Capture tokens before `import cetz.draw: *` shadows names like `line`/`fill`.
  let pad-x = theme.flowchart-node-pad-x / 1cm
  let pad-y = theme.flowchart-node-pad-y / 1cm
  let min-w = theme.flowchart-node-min-width / 1cm
  let node-gap = theme.flowchart-node-gap / 1cm
  let rank-gap = theme.flowchart-rank-gap / 1cm
  let back-margin = theme.flowchart-back-margin / 1cm
  let back-gap = theme.flowchart-back-gap / 1cm
  let edge-width = theme.flowchart-node-edge-width
  let edge-darken = theme.flowchart-node-edge-darken
  let node-outline = theme.flowchart-node-outline
  let node-fill = theme.flowchart-node-fill
  let label-size = theme.flowchart-label-size
  let label-color = theme.flowchart-label-color
  let dscale = theme.flowchart-decision-scale
  let io-slant = theme.flowchart-io-slant / 1cm
  let cyl-cap = theme.flowchart-cylinder-cap / 1cm
  let edge-stroke = theme.flowchart-edge-width + theme.flowchart-edge-color
  let line-w = theme.flowchart-edge-width / 1cm // sag tolerance for edge landings
  let arrow-fill = theme.flowchart-edge-color
  let arrow-scale = theme.flowchart-arrow-scale
  let elabel-size = theme.flowchart-edge-label-size
  let elabel-color = theme.flowchart-edge-label-color
  let elabel-fill = theme.flowchart-edge-label-fill
  let elabel-inset = theme.flowchart-edge-label-inset

  // Measure each label and give the node a box per shape (a diamond grows to hold
  // the label, a rounded rectangle rounds its corners, a parallelogram leans off vertical).
  let sized = g.cells.map(c => {
    let lbl = text(size: label-size, fill: label-color, c.label)
    let m = measure(lbl)
    let iw = calc.max(m.width / 1cm + 2 * pad-x, min-w)
    let ih = m.height / 1cm + 2 * pad-y
    // The router works in a canonical (cross, flow) space: `w` is the cross-axis
    // extent (growable by a merge), `h` the flow-axis extent. Most shapes are a plain
    // box that just swaps axes with the flow orientation; the parallelogram is
    // special — its slant always runs along the cross axis (so its flow-entry/exit
    // faces stay flat and edges attach flush), so the slant room is reserved in
    // whichever extent is the cross one.
    let (w, h) = if c.shape == "parallelogram" {
      if orientation == "horizontal" { (ih + io-slant, iw) } else {
        (iw + io-slant, ih)
      }
    } else if c.shape == "cylinder" {
      // A cylinder stands upright whatever the flow, so its cap room always
      // rides the final vertical extent: the flow extent in a vertical flow,
      // the cross extent in a horizontal one. Four cap heights: two for the
      // silhouette's caps, two so the front rim dips only to the label's top.
      if orientation == "horizontal" { (ih + 4 * cyl-cap, iw) } else {
        (iw, ih + 4 * cyl-cap)
      }
    } else {
      let (bw, bh) = if c.shape == "diamond" {
        (iw * dscale, ih * dscale)
      } else if c.shape == "rounded" {
        (iw + ih, ih)
      } else {
        (iw, ih)
      }
      if orientation == "horizontal" { (bh, bw) } else { (bw, bh) }
    }
    // `th` is the label-height thickness — the rounded rectangle's corner radius, so a
    // merge target that grows keeps flat faces (rounded corners, not a bulging capsule).
    (..c, lbl: lbl, w: w, h: h, th: ih)
  })

  // Pure placement: spine-aligned positions, merge-widened widths, and each long
  // edge's corridor route (see place.typ).
  let placed = place(
    sized,
    g.edges,
    g.ranks,
    node-gap: node-gap,
    rank-gap: rank-gap,
    pad-x: pad-x,
    back-margin: back-margin,
  )

  // Final node geometry for the canvas: placement plus each node's label and style.
  let pos = (:)
  for c in sized {
    pos.insert(str(c.index), (
      x: placed.x.at(str(c.index)),
      y: placed.y.at(str(c.index)),
      rank: c.rank,
      w: placed.w.at(str(c.index)),
      h: c.h,
      th: c.th,
      shape: c.shape,
      fill: c.fill,
      lbl: c.lbl,
    ))
  }
  let fanout = placed.fanout
  let route = placed.route

  cetz.canvas({
    import cetz.draw: *

    // Two x-coordinates within this are treated as the same column (a straight run).
    let straight-eps = 0.02

    // Everything below is computed in the canonical downward-flow space; a horizontal
    // flow is that picture transposed. `map` sends a canonical point to the canvas
    // (identity for a vertical flow), and is applied to every drawn coordinate — so
    // lines and boxes rotate but text, placed at `map(centre)`, stays upright.
    let map = if orientation == "horizontal" {
      p => (-p.at(1), -p.at(0))
    } else {
      p => p
    }

    // A node's outline for its shape, centred at (x, y). Border, as on the timeline
    // markers: a filled node is ringed by a deeper shade of its own fill; an unfilled
    // one takes the neutral outline. (Any non-colour paint has no `.darken`, so fall
    // back to the fill itself rather than panic.)
    let draw-node = p => {
      // The outline is the node's canonical box `map`ped onto the canvas (so lines and
      // corners transpose with the flow), while the label is placed upright at the
      // mapped centre — text never rotates. Because the parallelogram's slant is kept
      // along the cross axis and drawn in canonical space, its flow faces stay flat under the
      // map; the rounded-box radius is capped by `th` so a grown merge keeps flat faces.
      let (x, y, w, h) = (p.x, p.y, p.w, p.h)
      let fc = if p.fill == none { node-fill } else { p.fill }
      let edge = (
        edge-width
          + if p.fill == none {
            node-outline
          } else if type(p.fill) == color {
            p.fill.darken(edge-darken)
          } else {
            p.fill
          }
      )
      if p.shape == "rounded" {
        rect(
          map((x - w / 2, y - h / 2)),
          map((x + w / 2, y + h / 2)),
          radius: calc.min(w, h, p.th) / 2,
          fill: fc,
          stroke: edge,
        )
      } else if p.shape == "diamond" {
        line(
          map((x, y + h / 2)),
          map((x + w / 2, y)),
          map((x, y - h / 2)),
          map((x - w / 2, y)),
          close: true,
          fill: fc,
          stroke: edge,
        )
      } else if p.shape == "parallelogram" {
        line(
          map((x - w / 2, y - h / 2)),
          map((x + w / 2 - io-slant, y - h / 2)),
          map((x + w / 2, y + h / 2)),
          map((x - w / 2 + io-slant, y + h / 2)),
          close: true,
          fill: fc,
          stroke: edge,
        )
      } else if p.shape == "cylinder" {
        // A datastore stands upright whatever the flow, so it is drawn around
        // the mapped centre with unswapped extents — putting it through `map`
        // would lay it on its side. Silhouette first (sides + back of the top
        // rim + front of the bottom), then the front rim over the fill.
        let (fx, fy) = map((x, y))
        let (fw, fh) = if orientation == "horizontal" { (h, w) } else {
          (w, h)
        }
        let fa = fw / 2
        let ytop = fy + fh / 2 - cyl-cap // top rim ellipse centre
        let ybot = fy - fh / 2 + cyl-cap // bottom rim ellipse centre
        merge-path(close: true, fill: fc, stroke: edge, {
          line((fx - fa, ybot), (fx - fa, ytop))
          arc(
            (fx - fa, ytop),
            start: 180deg,
            stop: 0deg,
            radius: (fa, cyl-cap),
            anchor: "arc-start",
          )
          line((fx + fa, ytop), (fx + fa, ybot))
          arc(
            (fx + fa, ybot),
            start: 0deg,
            stop: -180deg,
            radius: (fa, cyl-cap),
            anchor: "arc-start",
          )
        })
        arc(
          (fx - fa, ytop),
          start: 180deg,
          stop: 360deg,
          radius: (fa, cyl-cap),
          anchor: "arc-start",
          stroke: edge,
        )
      } else {
        rect(
          map((x - w / 2, y - h / 2)),
          map((x + w / 2, y + h / 2)),
          fill: fc,
          stroke: edge,
        )
      }
      // The label sits at the node's centre — except in a cylinder, where the
      // visible body runs from the front rim down, so centre the label there.
      let lc = map((x, y))
      if p.shape == "cylinder" {
        lc = (lc.at(0), lc.at(1) - cyl-cap / 2)
      }
      content(lc, p.lbl)
    }

    // A point on a node's outline (top/bottom), nudged `toward` a target x — a
    // diamond's faces slope, so its ports ride up toward the sides. `spread` caps
    // how far along the face a port may sit.
    let attach = (p, toward, top, spread) => {
      let a = p.w / 2
      let b = p.h / 2
      let dx = calc.max(calc.min(toward - p.x, spread * a), -spread * a)
      // The bounding box overstates the landing face: a rounded box curves in at
      // its corners and a parallelogram's slant eats one end of each face. Clamp to
      // the flat span so an edge never points at the gap beside the outline (the
      // radius mirrors draw-node; a diamond's sloped faces are handled below). A
      // landing may run past the flat span while the corner arc has sagged by less
      // than a line width there (sag ≈ dx²/2r) — the tip still reads as touching,
      // and without that slack a hair-off-apex landing on a capsule end (a
      // horizontal terminal, whose entry face is all arc) snaps to the apex and
      // kinks an otherwise straight edge.
      if p.shape == "rounded" {
        let r = calc.min(p.w, p.h, p.th) / 2
        let flat = calc.max(a - r, 0) + calc.min(calc.sqrt(2 * r * line-w), r)
        dx = calc.max(calc.min(dx, flat), -flat)
      } else if p.shape == "parallelogram" {
        // Top face spans [-a + io-slant, a]; bottom face [-a, a - io-slant].
        if top {
          dx = calc.max(dx, calc.min(-a + io-slant, 0))
        } else {
          dx = calc.min(dx, calc.max(a - io-slant, 0))
        }
      } else if p.shape == "cylinder" {
        // Upright whatever the flow. Vertical flow lands on the cap's arc:
        // allow a landing while the arc has sagged less than a line width
        // (sag ≈ cap·dx²/2a²). Horizontal flow lands on the straight side
        // between the caps, with the same slack past its ends.
        if orientation == "horizontal" {
          let flat = (
            calc.max(a - cyl-cap, 0)
              + calc.min(calc.sqrt(2 * cyl-cap * line-w), cyl-cap)
          )
          dx = calc.max(calc.min(dx, flat), -flat)
        } else {
          let allow = if cyl-cap <= line-w { a } else {
            calc.min(a * calc.sqrt(2 * line-w / cyl-cap), a)
          }
          dx = calc.max(calc.min(dx, allow), -allow)
        }
      }
      let ey = if p.shape == "diamond" {
        let rise = b * (1 - calc.abs(dx) / a)
        if top { p.y + rise } else { p.y - rise }
      } else if top { p.y + b } else { p.y - b }
      (p.x + dx, ey)
    }
    // Place a branch label on the midpoint of the path's longest vertical run. A
    // label reads cleanly sitting on a vertical line (like the yes/no branches), but
    // its knockout box breaks up a short horizontal stub and looks like a gap in the
    // line. Fall back to the longest segment only if the path has no vertical run.
    let edge-label = (lbl, pts) => {
      let anchor = none
      let best = -1
      for i in range(pts.len() - 1) {
        let (ax, ay) = pts.at(i)
        let (bx, by) = pts.at(i + 1)
        let vertical = calc.abs(ax - bx) < straight-eps
        let score = (
          calc.abs(ay - by)
            + calc.abs(ax - bx)
            + if vertical { 1000 } else { 0 }
        )
        if score > best {
          best = score
          anchor = ((ax + bx) / 2, (ay + by) / 2)
        }
      }
      if anchor != none {
        content(
          map(anchor),
          box(
            fill: elabel-fill,
            inset: elabel-inset,
            text(size: elabel-size, fill: elabel-color, lbl),
          ),
        )
      }
    }

    // Diagram extent; back-edges climb a side channel, long edges take a corridor.
    let min-x = calc.min(..pos.values().map(p => p.x - p.w / 2))
    let max-x = calc.max(..pos.values().map(p => p.x + p.w / 2))
    let center-x = (min-x + max-x) / 2
    let left-i = 0
    let right-i = 0

    // Edges first, so nodes sit over the line ends.
    for (ei, e) in g.edges.enumerate() {
      let s = pos.at(str(e.from))
      let t = pos.at(str(e.to))
      if e.kind == "direct" {
        let forks = fanout.at(str(e.from), default: 0) >= 2
        let pts = if (
          orientation == "horizontal" and s.shape == "diamond" and forks
        ) {
          // A horizontal-flow decision that forks leaves through its cross faces (the
          // diamond's top and bottom points, in the final picture): out the vertex on
          // the child's side, then flow into the child — cleaner than crowding the
          // single flow vertex with both branches. (A lone child is the flow
          // continuing, so it falls through and exits straight on.) This assumes the
          // usual two-way split; 3+ children on one cross side would share a vertex.
          let side = if t.x > s.x { 1 } else { -1 }
          let exit = (s.x + side * s.w / 2, s.y)
          let entry = attach(t, t.x, true, 1.0)
          if calc.abs(t.x - s.x) >= s.w / 2 {
            // Child sits beyond the vertex: straight down the flank, then flow in.
            if calc.abs(exit.at(0) - entry.at(0)) < straight-eps {
              (exit, entry)
            } else {
              (exit, (entry.at(0), s.y), entry)
            }
          } else {
            // Child sits within the diamond's span: leave the vertex perpendicular (a
            // short stub past the point, so it reads as a right-angle exit like the
            // clear case), then flow along and drop into the child's column below the
            // diamond, so the run never cuts back through the body.
            let out = s.x + side * (s.w / 2 + node-gap / 2)
            let clear-y = s.y - s.h / 2 - rank-gap / 2
            (exit, (out, s.y), (out, clear-y), (entry.at(0), clear-y), entry)
          }
        } else {
          // Leave at the source's x (a multi-output node spreads toward each target)
          // and run straight into the target's flow-entry face; bend only if the
          // source overhangs the target.
          let exit = attach(
            s,
            if fanout.at(str(e.from), default: 0) == 1 { s.x } else { t.x },
            false,
            0.7,
          )
          let entry = attach(t, exit.at(0), true, 1.0)
          if calc.abs(exit.at(0) - entry.at(0)) < straight-eps {
            (exit, entry)
          } else {
            let my = (exit.at(1) + entry.at(1)) / 2
            (exit, (exit.at(0), my), (entry.at(0), my), entry)
          }
        }
        line(
          ..pts.map(map),
          stroke: edge-stroke,
          mark: (end: ">", fill: arrow-fill, scale: arrow-scale),
        )
        if e.label != none { edge-label(e.label, pts) }
      } else if e.kind == "back" {
        // A loop climbs a side channel: out of the source's side, up, into the target's.
        let left = s.x <= center-x
        let ch = if left {
          min-x - back-margin - left-i * back-gap
        } else {
          max-x + back-margin + right-i * back-gap
        }
        if left { left-i += 1 } else { right-i += 1 }
        // Side endpoints sit on the outline at mid-height: only the parallelogram
        // differs from its bounding box — its slanted side crosses mid-height
        // io-slant/2 in from the corner.
        let side-a = p => (
          p.w / 2 - if p.shape == "parallelogram" { io-slant / 2 } else { 0 }
        )
        let sx = if left { s.x - side-a(s) } else { s.x + side-a(s) }
        let tx = if left { t.x - side-a(t) } else { t.x + side-a(t) }
        let pts = ((sx, s.y), (ch, s.y), (ch, t.y), (tx, t.y))
        line(
          ..pts.map(map),
          stroke: edge-stroke,
          mark: (end: ">", fill: arrow-fill, scale: arrow-scale),
        )
        if e.label != none { edge-label(e.label, pts) }
      } else {
        // A long edge drops down its corridor into the target's top — the corridor,
        // vertical run, and entry share one x, so the drop is straight whenever the
        // source's column is clear. A decision exits by the side vertex facing the
        // corridor (kept outside the diamond, so the run leads away from it); any
        // other shape (or a boxed-in diamond) exits its bottom centre and drops
        // clear before jogging across only when the column is blocked.
        let r = route.at(str(ei))
        let cx = r.cx
        let side-ok = r.side-ok
        let entry = attach(t, r.entry, true, 1.0)
        let ay = entry.at(1) + rank-gap / 2
        let head = if side-ok {
          let sx = if cx < s.x { s.x - s.w / 2 } else { s.x + s.w / 2 }
          ((sx, s.y), (cx, s.y))
        } else {
          let dy = s.y - s.h / 2 - rank-gap / 2
          ((s.x, s.y - s.h / 2), (s.x, dy), (cx, dy))
        }
        let pts = head + ((cx, ay), (entry.at(0), ay), entry)
        line(
          ..pts.map(map),
          stroke: edge-stroke,
          mark: (end: ">", fill: arrow-fill, scale: arrow-scale),
        )
        if e.label != none { edge-label(e.label, pts) }
      }
    }

    for p in pos.values() { draw-node(p) }
  })
}
