#import "/src/field/elements.typ": bytes
#import "/src/field/model.typ": model

// A single 2-byte field occupies bits 0–15 (end inclusive), derived from its
// width — the author never types an offset.
#let fields = model((bytes(2)[Source Port],))

#assert.eq(fields.len(), 1)
#let f = fields.first()
#assert.eq(f.start, 0)
#assert.eq(f.end, 15)
