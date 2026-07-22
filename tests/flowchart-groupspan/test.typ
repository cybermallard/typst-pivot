// A group whose members span several ranks around an interleaved non-member
// (the RBVM shape: TI/EPSS at the top, the CMDB two ranks down, fed by the
// non-member normalization diamond between them). Anchors the cohesion
// recovery: the far member is pulled under its group-mates so the box stays
// a narrow column, the excluded nodes sit clear of it, and — the invariant —
// nothing overlaps.
#import "@local/pivot:0.2.0": edge, flowchart, group, node, palette

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("easm", [EASM], fill: palette.sky),
  node("cspm", [CSPM], fill: palette.sky),
  node("vmscan", [VM scan], fill: palette.sky),
  node("ctem", [CTEM], fill: palette.sky),
  node("norm", [Normalize], shape: "diamond", fill: palette.orange),
  node("ti", [Threat intel], fill: palette.purple),
  node("epss", [EPSS], fill: palette.purple),
  node("cmdb", [CMDB], shape: "cylinder", fill: palette.green),
  node("rbvm", [Score engine], shape: "diamond", fill: palette.orange),
  node("score", [Risk score], fill: palette.green),
  edge("easm", "norm"),
  edge("cspm", "norm"),
  edge("vmscan", "norm"),
  edge("ctem", "norm"),
  edge("norm", "cmdb", label: [overlay]),
  edge("norm", "rbvm", label: [vulns]),
  edge("ti", "rbvm"),
  edge("epss", "rbvm"),
  edge("cmdb", "rbvm", label: [assets]),
  edge("rbvm", "score"),
  group("tel", [Telemetry], "easm", "cspm", "vmscan", "ctem"),
  group("enr", [Enrichment], "ti", "epss", "cmdb"),
)
