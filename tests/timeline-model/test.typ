#import "/src/timeline/elements.typ": event
#import "/src/timeline/model.typ": model

// The model enumerates events in author order, carries their fields through, and
// leaves `none` for an omitted time/description — a sparse event is title-only.
#let evs = model((
  event(time: "09:32", description: [Macro run.])[Initial access],
  event(shape: "square")[Beacon],
))

#assert.eq(evs.map(e => e.index), (0, 1))
#assert.eq(evs.map(e => e.time), ("09:32", none))
#assert.eq(evs.map(e => e.shape), ("circle", "square"))
#assert.eq(evs.at(1).description, none)
#assert(evs.at(0).description != none)
