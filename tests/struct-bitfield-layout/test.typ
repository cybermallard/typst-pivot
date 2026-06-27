#import "/src/field/elements.typ": bytes, bits
#import "/src/field/model.typ": model
#import "/src/struct/layout.typ": layout

// A byte carved into bit-fields collapses to one "bits" entry (the byte's
// height), with the sub-fields carried as cells; whole-byte fields stay "box".
#let e = layout(
  model((bytes(2)[M], bits(2)[A], bits(2)[B], bits(4)[C], bytes(1)[Z])),
  scale: 0.5,
  min-height: 0.5,
  max-height: 4.0,
)

#assert.eq(e.map(x => x.type), ("box", "bits", "box"))
// the bit-group spans one byte (8 bits) starting at byte 2 (bit 16)
#assert.eq(e.at(1).start, 16)
#assert.eq(e.at(1).size, 8)
#assert.eq(e.at(1).cells.map(c => c.start), (16, 18, 20))
#assert.eq(e.at(1).cells.map(c => c.size), (2, 2, 4))

// A field that straddles a byte boundary keeps its whole run in one strip:
// 3 flag bits + a 13-bit field = one 2-byte "bits" entry (cf. IPv4 flags+frag).
#let s = layout(model((bits(3)[Flags], bits(13)[Offset])))
#assert.eq(s.map(x => x.type), ("bits",))
#assert.eq(s.at(0).size, 16)
#assert.eq(s.at(0).cells.map(c => c.size), (3, 13))

// A sub-byte run that never returns to a byte boundary (malformed / truncated)
// still terminates and yields one faithful partial-byte "bits" entry.
#let t = layout(model((bits(3)[X],)))
#assert.eq(t.map(x => x.type), ("bits",))
#assert.eq(t.at(0).size, 3)
#assert.eq(t.at(0).cells.map(c => c.size), (3,))
