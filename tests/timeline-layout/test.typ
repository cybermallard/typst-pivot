#import "/src/timeline/elements.typ": event
#import "/src/timeline/model.typ": model
#import "/src/timeline/layout.typ": layout

// Layout gives each event an ordinal `slot` and an alternating `side` (+1 / -1)
// so consecutive labels fall on opposite sides of the axis and don't collide.
#let evs = layout(model((event[A], event[B], event[C], event[D])))

#assert.eq(evs.map(e => e.slot), (0, 1, 2, 3))
#assert.eq(evs.map(e => e.side), (1, -1, 1, -1))
