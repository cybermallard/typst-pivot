// Cascaded widening (the shape that regressed): `Mark clean` widens for a long
// input from the first decision and moves during relaxation; `Report outcome`
// merges on top of that moved parent. Anchors that the merge terminal spans both
// incoming columns with its padding to spare — both arrows land inset on the flat
// top face, never on the rounded corners.
#import "@local/pivot:0.2.0": edge, flowchart, node, palette

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
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
