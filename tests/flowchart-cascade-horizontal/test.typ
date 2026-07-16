// The cascaded-widening graph transposed: the same placement runs in canonical
// space and the map turns it a quarter, so the widened merge seats its inputs
// across the flow (the terminal grows tall, arrows land inset on its flat left
// face). Anchors that the convergence fix and the shape-aware landings survive
// the horizontal orientation.
#import "@local/pivot:0.2.0": edge, flowchart, node, palette

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  orientation: "horizontal",
  node("in", [Suspected host], shape: "rounded"),
  node("task", [UpdateHealthCheck task present?], shape: "diamond"),
  node("mem", [Scan memory with EDR], shape: "parallelogram"),
  node("c2", [Beaconing to the C2 domain?], shape: "diamond"),
  node("ir", [Raise incident], fill: palette.vermillion),
  node("clear", [Mark clean], fill: palette.green),
  node("out", [Report outcome], shape: "rounded"),
  edge("in", "task"),
  edge("task", "mem", label: [yes]),
  edge("task", "clear", label: [no]),
  edge("mem", "c2"),
  edge("c2", "ir", label: [yes]),
  edge("c2", "clear", label: [no]),
  edge("ir", "out"),
  edge("clear", "out"),
)
