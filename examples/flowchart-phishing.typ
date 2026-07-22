#import "@local/pivot:0.3.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

// A phishing-report triage. Two decisions can both route to Quarantine: the
// "headers spoofed" branch reaches it as a long edge, exiting the diamond by its
// side point and dropping straight down its own column into the merge.
#flowchart(
  node("in", [Email reported], shape: "rounded"),
  node("hdr", [Headers spoofed?], shape: "diamond"),
  node("url", [Malicious URL?], shape: "diamond"),
  node("quar", [Quarantine]),
  node("fp", [Mark false positive]),
  node("notify", [Notify user]),
  node("out", [Close ticket], shape: "rounded"),
  edge("in", "hdr"),
  edge("hdr", "quar", label: [yes]),
  edge("hdr", "url", label: [no]),
  edge("url", "quar", label: [yes]),
  edge("url", "fp", label: [no]),
  edge("quar", "notify"),
  edge("fp", "notify"),
  edge("notify", "out"),
)
