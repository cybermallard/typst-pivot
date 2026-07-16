// The cylinder (datastore) stands upright in both orientations. Top, vertical:
// a two-parent merge lands its arrows on the top cap's arc, pulled toward the
// apex so no tip floats beside the curve; the filled store widens for the merge
// while its caps stay fixed, and an unfilled cylinder renders as line-art.
// Bottom, the same graph horizontal: edges meet the cylinders' straight sides,
// and the datastores still read as upright databases.
#import "@local/pivot:0.2.0": edge, flowchart, node, palette

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart(
  node("a", [Sensor A]),
  node("b", [Sensor B]),
  node("store", [Event store], shape: "cylinder", fill: palette.sky),
  node("corr", [Correlate]),
  node("arch", [Archive], shape: "cylinder"),
  edge("a", "store"),
  edge("b", "store"),
  edge("store", "corr"),
  edge("corr", "arch"),
)

#v(1cm)

#flowchart(
  orientation: "horizontal",
  node("a", [Sensor A]),
  node("b", [Sensor B]),
  node("store", [Event store], shape: "cylinder", fill: palette.sky),
  node("corr", [Correlate]),
  node("arch", [Archive], shape: "cylinder"),
  edge("a", "store"),
  edge("b", "store"),
  edge("store", "corr"),
  edge("corr", "arch"),
)
