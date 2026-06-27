#import "/src/field/elements.typ": bytes
#import "/src/field/model.typ": model
#import "/src/struct/layout.typ": layout

// Heights are proportional to byte size, floored at min and capped at max.
// scale/min/max chosen as exact binary fractions so float equality is safe.
//   A = 4 B -> 4*0.5 = 2.0 (== max, not clamped)
//   B = 1 B -> 1*0.5 = 0.5 (== min)
//   C = 8 B -> 8*0.5 = 4.0 -> clamped to 2.0
#let e = layout(
  model((bytes(4)[A], bytes(1)[B], bytes(8)[C])),
  scale: 0.5,
  min-height: 0.5,
  max-height: 2.0,
)

#assert.eq(e.map(x => x.size), (32, 8, 64))
#assert.eq(e.map(x => x.height), (2.0, 0.5, 2.0))
#assert.eq(e.map(x => x.top), (0.0, 2.0, 2.5))
#assert.eq(e.map(x => x.clamped), (false, false, true))
