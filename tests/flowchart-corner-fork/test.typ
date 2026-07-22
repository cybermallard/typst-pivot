// An entry that overshoots a rounded corner: `sort`'s only child `ok` is shoved
// off its parent's column by the wide sibling branch, so the edge from `sort`
// heads for `ok`'s far side. It must land clamped on the rounded box's flat top
// span (then jog), never pointing at the gap beside the curved corner. `sort`
// itself is anchored by its parent, so the offset survives relaxation.
#import "@local/pivot:0.3.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("start", [Start], shape: "rounded"),
  node("collect", [Collect]),
  node("sort", [Sort]),
  node("enrich", [Enrich each event with asset, identity and threat context]),
  node("ok", [Ok], shape: "rounded"),
  edge("start", "collect"),
  edge("start", "sort"),
  edge("collect", "enrich"),
  edge("sort", "ok"),
)
