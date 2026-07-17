// Degenerate graphs must render, not crash (the "designing for the abnormal"
// rubric): an empty diagram draws nothing; a lone node, a self-loop, and a
// two-node cycle each lay out and route without error. A self-loop that also
// has an onward edge (a poll-until-ready step) is the case that must keep its
// rank valid — the self-loop stays out of the ranking graph.
#import "@local/pivot:0.2.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart()
#flowchart(node("solo", [Solo]))
#flowchart(node("a", [A]), edge("a", "a"))
#flowchart(node("x", [X]), node("y", [Y]), edge("x", "y"), edge("y", "x"))
#flowchart(
  node("p", [Poll]),
  node("q", [Done]),
  edge("p", "p", label: [wait]),
  edge("p", "q", label: [ok]),
)
