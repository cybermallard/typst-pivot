#import "/src/field/elements.typ": bytes, bits
#import "/src/field/model.typ": model

// Fields are positioned cumulatively from their widths (bytes -> n*8 bits,
// bits -> n bits); `end` is inclusive.
#let fields = model((bytes(2)[A], bits(4)[B], bits(4)[C]))
#assert.eq(fields.map(f => (f.start, f.end)), ((0, 15), (16, 19), (20, 23)))
