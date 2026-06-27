#import "/src/field/elements.typ": bytes
#import "/src/field/model.typ": model
#import "/src/field/layout.typ": layout

// A field that crosses bits-per-row splits into one segment per row it touches,
// flagged `continues` (carries on) and `continued` (arrived from above).
// A: bits 0-15. B: bits 16-63 (48 bits) -> row 0 cols 16-31, then row 1 cols 0-31.
#let segs = layout(model((bytes(2)[A], bytes(6)[B])), bits-per-row: 32)

#assert.eq(
  segs.map(s => (s.row, s.at("col-start"), s.at("col-end"), s.continued, s.continues)),
  (
    (0, 0, 15, false, false),
    (0, 16, 31, false, true),
    (1, 0, 31, true, false),
  ),
)
