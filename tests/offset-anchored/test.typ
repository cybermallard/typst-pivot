#import "/src/field/elements.typ": bytes
#import "/src/field/model.typ": model

// `at:` anchors a field at an absolute position; the skipped span before it
// becomes an implicit gap (kind "gap"). `bytes(.., at: k)` is a byte offset, so
// `at: 8` lands B at bit 64; `model` works in bits.
#let fields = model((bytes(2)[A], bytes(2, at: 8)[B]))

#assert.eq(
  fields.map(f => (f.kind, f.start, f.end)),
  (("field", 0, 15), ("gap", 16, 63), ("field", 64, 79)),
)
