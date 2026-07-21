// Outline (skeleton) nodes: `outline: <colour>` draws a node with no fill and
// that colour on both the border and the label text — the fill-less mirror of
// `fill:`. Anchors that the accent reaches the text and the border, that it
// works across shapes, that a plain unfilled node stays the neutral skeleton,
// and that a solid `fill:` node renders correctly in the same diagram.
// Outline colours are the base Okabe–Ito hues, not `palette.*`: those are
// lightened for use as fills behind black text, so as outline stroke + text on
// white they wash out — the base hues keep their contrast as a foreground.
#import "@local/pivot:0.2.0": edge, flowchart, node, palette

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("scan", [Scan file], shape: "rounded", fill: palette.sky),
  node("check", [Malicious?], shape: "diamond"),
  node("secure", [Verdict: Secure], shape: "rounded", outline: rgb("#009E73")),
  node("block", [Block & alert], outline: rgb("#D55E00")),
  node("fp", [Verdict: False positive], shape: "rounded"),
  node("store", [Case store], shape: "cylinder", outline: rgb("#0072B2")),
  edge("scan", "check"),
  edge("check", "secure", label: [no]),
  edge("check", "block", label: [yes]),
  edge("secure", "fp"),
  edge("block", "store"),
)
