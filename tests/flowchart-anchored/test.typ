// Unanchored nodes (no direct edges). Top: a single-feed store chases its
// corridor to a dead-straight drop past the wide row — column, corridor and
// entry coincide. Second: a several-feed source neither chases nor reorders
// (its targets' corridors stay near the targets, so nothing balloons); its
// edges jog as usual. Third: a sink is never unanchored — its deepest feeder
// is always a direct edge — so it sits under that feeder and widens to seat
// the long entries. Bottom: the single-feed alignment survives the transpose.
#import "@local/pivot:0.3.0": edge, flowchart, node, palette

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("in", [Alert], shape: "rounded"),
  node("tri", [Triage]),
  node("wide", [Correlate with recent activity across the estate]),
  node("act", [Contain host]),
  node("out", [Report], shape: "rounded"),
  node("store", [Threat intel], shape: "cylinder", fill: palette.sky),
  edge("in", "tri"),
  edge("tri", "wide"),
  edge("wide", "act"),
  edge("act", "out"),
  edge("store", "act"),
)

#v(1cm)

#flowchart(
  node("ti", [Threat intel feed], shape: "cylinder", fill: palette.sky),
  node("a0", [Collect logs]),
  node("a1", [Normalise]),
  node("a2", [Enrich events]),
  node("a3", [Store]),
  node("b0", [Watch DNS]),
  node("b1", [Resolve]),
  node("b2", [Score domains]),
  node("b3", [Alert]),
  edge("a0", "a1"),
  edge("a1", "a2"),
  edge("a2", "a3"),
  edge("b0", "b1"),
  edge("b1", "b2"),
  edge("b2", "b3"),
  edge("ti", "a2"),
  edge("ti", "b2"),
)

#v(1cm)

#flowchart(
  node("a0", [Endpoint agent]),
  node("b0", [Proxy]),
  node("b1", [Parse logs]),
  node("d0", [Firewall]),
  node("d1", [Filter noise]),
  node("d2", [Aggregate]),
  node("siem", [SIEM], shape: "cylinder", fill: palette.green),
  edge("b0", "b1"),
  edge("d0", "d1"),
  edge("d1", "d2"),
  edge("a0", "siem"),
  edge("b1", "siem"),
  edge("d2", "siem"),
)

#v(1cm)

#flowchart(
  orientation: "horizontal",
  node("in", [Alert], shape: "rounded"),
  node("tri", [Triage]),
  node("wide", [Correlate with recent activity across the estate]),
  node("act", [Contain host]),
  node("out", [Report], shape: "rounded"),
  node("store", [Threat intel], shape: "cylinder", fill: palette.sky),
  edge("in", "tri"),
  edge("tri", "wide"),
  edge("wide", "act"),
  edge("act", "out"),
  edge("store", "act"),
)
