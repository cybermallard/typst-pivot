#import "@local/pivot:0.1.0": flowchart, node, edge

#set page(width: auto, height: auto, margin: 0.5cm)

// A malware-triage decision flow. Node shape marks the role — rounded (start /
// end), diamond (a decision), parallelogram (a manual/automated step feeding
// data), rectangle (an action) — and the branches are labelled on their edges.
#flowchart(
  node("in", [Suspicious file], shape: "rounded"),
  node("hash", [Known-bad hash?], shape: "diamond"),
  node("block", [Block & alert]),
  node("det", [Detonate in sandbox], shape: "parallelogram"),
  node("mal", [Malicious behaviour?], shape: "diamond"),
  node("ir", [Raise incident]),
  node("clear", [Mark benign]),
  node("out", [Report], shape: "rounded"),
  edge("in", "hash"),
  edge("hash", "block", label: [yes]),
  edge("hash", "det", label: [no]),
  edge("det", "mal"),
  edge("mal", "ir", label: [yes]),
  edge("mal", "clear", label: [no]),
  edge("ir", "out"),
  edge("clear", "out"),
  edge("block", "out"),
)
