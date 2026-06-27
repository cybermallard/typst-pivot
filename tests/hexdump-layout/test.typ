#import "/src/hexdump/layout.typ": (
  ascii, hex-byte, hex-offset, legend-columns, printable, rows,
)

// Chunking: 20 bytes at 16/row -> rows of 16 and 4, offsets 0 and 16.
#let rs = rows(range(0, 20), per: 16)
#assert.eq(rs.len(), 2)
#assert.eq(rs.at(0).offset, 0)
#assert.eq(rs.at(0).bytes.len(), 16)
#assert.eq(rs.at(1).offset, 16)
#assert.eq(rs.at(1).bytes, (16, 17, 18, 19))

// Empty input -> no rows (must not panic).
#assert.eq(rows(()), ())

// Hex formatting: zero-padded, upper-case, two digits.
#assert.eq(hex-byte(0), "00")
#assert.eq(hex-byte(13), "0D")
#assert.eq(hex-byte(255), "FF")
#assert.eq(hex-offset(0), "00000000")
#assert.eq(hex-offset(16), "00000010")

// ASCII gutter: printable renders, control/high bytes collapse to ".".
#assert.eq(ascii(0x41), "A")
#assert.eq(ascii(0x20), " ")
#assert.eq(ascii(0x7e), "~")
#assert.eq(ascii(0x1f), ".")
#assert.eq(ascii(0x7f), ".")
#assert.eq(printable(0x19), false)

// Legend columns: aim for 3 a column, capped at 3 columns, balanced split.
#let col-sizes = n => {
  let r = legend-columns(n)
  range(0, r.cols).map(c => r.positions.filter(p => p.at(0) == c).len())
}
#assert.eq(legend-columns(0), (cols: 0, rows: 0, positions: ()))
#assert.eq(legend-columns(3).cols, 1) // 1 column up to 3
#assert.eq(col-sizes(3), (3,))
#assert.eq(legend-columns(4).cols, 2) // switches to 2 at 4
#assert.eq(col-sizes(4), (2, 2)) // balanced, not (3, 1)
#assert.eq(col-sizes(6), (3, 3))
#assert.eq(legend-columns(7).cols, 3) // switches to 3 at 7
#assert.eq(col-sizes(7), (3, 2, 2)) // balanced, not (3, 3, 1)
#assert.eq(col-sizes(9), (3, 3, 3))
#assert.eq(legend-columns(11).cols, 3) // capped at 3 columns
#assert.eq(col-sizes(11), (4, 4, 3)) // columns grow taller past 9
// Reading order is column-major: entry k=3 starts column 1 at row 0.
#assert.eq(legend-columns(7).positions.at(3), (1, 0))
