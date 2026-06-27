#import "/src/field/elements.typ": bits, gap
#import "/src/field/model.typ": model

// An explicit `gap(n)` becomes a kind-"gap" field positioned in the flow,
// distinct from the surrounding kind-"field" fields.
#let fields = model((bits(1)[A], gap(2), bits(1)[B]))

#assert.eq(
  fields.map(f => (f.kind, f.start, f.end)),
  (("field", 0, 0), ("gap", 1, 2), ("field", 3, 3)),
)
