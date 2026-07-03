#import "@local/pivot:0.2.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

// A left-to-right alert-enrichment pipeline (`orientation: "horizontal"`). The flow reads as
// a line: dedup, enrich, decide, then the two dispositions merge back into one notify
// step — which widens across the flow (here, vertically) to seat both inputs.
#flowchart(
  orientation: "horizontal",
  node("in", [Alert], shape: "rounded"),
  node("dedup", [Deduplicate]),
  node("enrich", [Enrich with TI], shape: "parallelogram"),
  node("known", [Known campaign?], shape: "diamond"),
  node("inc", [Create incident]),
  node("watch", [Add to watchlist]),
  node("out", [Notify SOC], shape: "rounded"),
  edge("in", "dedup"),
  edge("dedup", "enrich"),
  edge("enrich", "known"),
  edge("known", "inc", label: [yes]),
  edge("known", "watch", label: [no]),
  edge("inc", "out"),
  edge("watch", "out"),
)
