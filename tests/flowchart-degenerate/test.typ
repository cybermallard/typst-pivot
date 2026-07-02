// Degenerate graphs must render, not crash (the "designing for the abnormal"
// rubric): an empty diagram draws nothing; a lone node, a self-loop, and a
// two-node cycle each lay out and route without error.
#import "@local/pivot:0.1.0": edge, flowchart, node

#set page(width: auto, height: auto, margin: 0.5cm)

#flowchart()
#flowchart(node("solo", [Solo]))
#flowchart(node("a", [A]), edge("a", "a"))
#flowchart(node("x", [X]), node("y", [Y]), edge("x", "y"), edge("y", "x"))
