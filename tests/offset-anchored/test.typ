#import "/src/field/elements.typ": bytes
#import "/src/field/model.typ": model

// `at:` anchors a field at an absolute position; the skipped span before it
// becomes an implicit gap (kind "gap"). Unit -> bit conversion happens at the
// packet/struct boundary, so `model` works in bits.
#let fields = model((bytes(2)[A], bytes(2, at: 64)[B]))

#assert.eq(
  fields.map(f => (f.kind, f.start, f.end)),
  (("field", 0, 15), ("gap", 16, 63), ("field", 64, 79)),
)
