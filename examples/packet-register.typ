#import "@local/pivot:0.1.0": bits, packet

#set page(width: auto, height: auto, margin: 8pt)
#set text(font: "DejaVu Sans Mono")

// A 16-bit status register packed with flags — a crowded row whose callouts
// would cross, so it switches to the single outside-the-frame column.
#packet(
  bits-per-row: 16,
  bits(1)[Carry], bits(1)[Zero], bits(1)[Sign], bits(1)[Overflow],
  bits(1)[Parity], bits(1)[Aux], bits(1)[IRQ], bits(1)[FIQ],
  bits(4)[Mode], bits(4)[Priority],
)
