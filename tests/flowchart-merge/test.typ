// Multiple long edges into one merge: `scan` and `enrich` both reach `report`
// across more than one rank. Each drops down its own source column, so the merge
// widens to seat both entries side by side without them colliding.
#import "@local/pivot:0.1.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("scan", [Scan], shape: "rounded"),
  node("enrich", [Enrich]),
  node("triage", [Triage]),
  node("report", [Report], shape: "rounded"),
  edge("scan", "enrich"),
  edge("enrich", "triage"),
  edge("triage", "report"),
  edge("scan", "report"), // spans three ranks -> long
  edge("enrich", "report"), // spans two ranks -> long
)
