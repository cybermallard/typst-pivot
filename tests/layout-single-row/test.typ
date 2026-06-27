#import "/src/field/elements.typ": bytes
#import "/src/field/model.typ": model
#import "/src/field/layout.typ": layout

// Fields that fit within bits-per-row produce one segment each, with no
// continuation across rows.
#let segs = layout(model((bytes(2)[A], bytes(2)[B])), bits-per-row: 32)

#assert.eq(
  segs.map(s => (s.row, s.at("col-start"), s.at("col-end"), s.continued, s.continues)),
  ((0, 0, 15, false, false), (0, 16, 31, false, false)),
)
