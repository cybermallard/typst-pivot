// A dense real-world architecture (the SAIF reference's topology): a five-way
// fan-in to one datastore, two feeds from a threat-intel store, parallel
// service tiers, and blocking terminals. Anchors the dense-graph guarantees:
// the sink widens only within max-reach (no page-wide platter — far feeds jog
// into allocated seats), every arrow into a node has its own spaced seat,
// jogging corridors take separate lanes at separate approach heights, and
// edge labels dodge each other, the nodes, and crossing lines.
#import "@local/pivot:0.3.0": edge, flowchart, node, palette

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
  node("providers", [Providers], shape: "cylinder"),
  node("external", [External APIs]),
  node("kill", [Kill], shape: "rounded", fill: palette.vermillion),
  node("drop", [Drop], shape: "rounded", fill: palette.vermillion),
  edge("trigger", "inbound", label: [payload]),
  edge("ti", "inbound", label: [signatures]),
  edge("ti", "firewall", label: [hashes]),
  edge("inbound", "orch", label: [sanitized]),
  edge("orch", "sandbox", label: [PoC]),
  edge("orch", "llm", label: [queries]),
  edge("orch", "firewall", label: [actions]),
  edge("inbound", "siem", label: [masked]),
  edge("sandbox", "siem", label: [telemetry]),
  edge("orch", "siem", label: [traces]),
  edge("llm", "siem", label: [costs]),
  edge("firewall", "siem", label: [skills]),
  edge("llm", "providers", label: [ZDR]),
  edge("firewall", "external", label: [vetted]),
  edge("firewall", "kill", label: [toxic]),
  edge("inbound", "drop", label: [blocked]),
)
