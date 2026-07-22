// Groups: titled boxes around related nodes. Anchors the guarantees — a
// nested pair draws border-in-border with stacked title bands, members stay
// inside and outsiders outside, unrelated lines route around the box, and the
// three border styles (plus a coloured custom stroke and a tint fill) render.
// The horizontal chart moves the title band to the final top edge.
#import "@local/pivot:0.3.0": edge, flowchart, group, node, palette

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("trigger", [Trigger], fill: palette.sky),
  node("ti", [Threat intel], shape: "cylinder", fill: palette.green),
  node("inbound", [Inbound gateway], fill: palette.orange),
  node("orch", [Orchestrator], fill: palette.purple),
  node("sandbox", [Sandbox], shape: "cylinder", fill: palette.sky),
  node("llm", [LLM gateway], fill: palette.orange),
  node("firewall", [Tool firewall], fill: palette.orange),
  node("siem", [SIEM], shape: "cylinder", fill: palette.green),
  node("drop", [Drop], shape: "rounded", fill: palette.vermillion),
  edge("trigger", "inbound", label: [payload]),
  edge("ti", "inbound", label: [signatures]),
  edge("ti", "firewall", label: [hashes]),
  edge("inbound", "orch", label: [sanitized]),
  edge("orch", "sandbox", label: [PoC]),
  edge("orch", "llm", label: [queries]),
  edge("orch", "firewall", label: [actions]),
  edge("inbound", "siem", label: [masked]),
  edge("orch", "siem", label: [traces]),
  edge("inbound", "drop", label: [blocked]),
  // `border-color:` + an opaque `fill:` (auto-washed to a tint) on a keyword
  // solid stroke.
  group(
    "env",
    [Secure Agent Environment],
    "inbound",
    "orch",
    "sandbox",
    "llm",
    "firewall",
    stroke: "solid",
    border-color: palette.green,
    fill: palette.green,
  ),
  // `fill:` only, opaque — auto-tinted, default grey dashed border.
  group("gov", [SAIF Governance], "ti", "siem", "env", fill: palette.blue),
)

#flowchart(
  orientation: "horizontal",
  node("in", [Alert], shape: "rounded", fill: palette.sky),
  node("tri", [Triage], fill: palette.orange),
  node("enr", [Enrich], fill: palette.orange),
  node("out", [Report], shape: "rounded", fill: palette.blue),
  edge("in", "tri"),
  edge("tri", "enr", label: [valid]),
  edge("enr", "out"),
  group(
    "soc",
    [SOC pipeline],
    "tri",
    "enr",
    stroke: (paint: palette.blue, thickness: 1pt, dash: "dashed"),
    fill: palette.sky.transparentize(85%),
  ),
)
