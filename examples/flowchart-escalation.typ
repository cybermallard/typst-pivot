#import "@local/pivot:0.2.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

// A left-to-right alert-escalation loop (`direction: "horizontal"`). It exercises the
// routing that a rightward flow transposes: a decision that forks (yes/no leave the
// diamond's top and bottom points), a decision with a single onward path (flows
// straight through), and a back edge — the loop from "More alerts?" climbs into a
// channel above the body and drops back into "Triage".
#flowchart(
  direction: "horizontal",
  node("start", [Alert raised], shape: "rounded"),
  node("triage", [Triage]),
  node("sev", [Severity > high?], shape: "diamond"),
  node("esc", [Escalate to IR]),
  node("mon", [Monitor]),
  node("contain", [Contain host]),
  node("more", [More alerts?], shape: "diamond"),
  node("close", [Close], shape: "rounded"),
  edge("start", "triage"),
  edge("triage", "sev"),
  edge("sev", "esc", label: [yes]),
  edge("sev", "mon", label: [no]),
  edge("esc", "contain"),
  edge("contain", "more"),
  edge("mon", "more"),
  edge("more", "triage", label: [yes]),
  edge("more", "close", label: [no]),
)
