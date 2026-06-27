#import "/src/field/elements.typ": bits
#import "/src/field/model.typ": model
#import "/src/field/layout.typ": layout

// A field's `fill:` carries through model and layout to the segment, so the
// renderer can highlight it.
#let segs = layout(model((bits(8, fill: red)[A],)))

#assert.eq(segs.first().fill, red)
