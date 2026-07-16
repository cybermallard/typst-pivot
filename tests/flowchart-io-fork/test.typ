// Parallelogram faces are shorter than their bounding box: the slant eats one end
// of each. Top: a minimum-width io node forking two children — its exit toward
// the far child spreads along the bottom face and must clamp onto the face's
// slanted end, not overhang it. Bottom: `tag`'s only child is an io node shoved
// off its parent's column by the wide sibling branch — the entry heads for the
// slanted end of the child's top face and must clamp onto it. Both land on the
// outline.
#import "@local/pivot:0.2.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("scan", [Scan], shape: "parallelogram"),
  node("a", [Quarantine the affected endpoints and archive volatile memory]),
  node("b", [Log]),
  edge("scan", "a", label: [hit]),
  edge("scan", "b", label: [miss]),
)

#v(1cm)

#flowchart(
  node("start", [Start], shape: "rounded"),
  node("collect", [Collect]),
  node("tag", [Tag]),
  node("enrich", [Enrich each event with asset, identity and threat context]),
  node("io", [Io], shape: "parallelogram"),
  edge("start", "collect"),
  edge("start", "tag"),
  edge("collect", "enrich"),
  edge("tag", "io"),
)
