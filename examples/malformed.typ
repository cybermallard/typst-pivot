#import "@local/pivot:0.1.0": bits, bytes, packet, palette

#set page(width: auto, height: auto, margin: 6pt)
#set text(font: "DejaVu Sans Mono")

// A malformed packet: a bogus length field (highlighted) and a structure that
// doesn't fill its rows — the last row is ragged. pivot draws it faithfully
// rather than refusing it.
#packet(
  bytes(1)[Type], bytes(1)[Code], bytes(2)[Checksum],
  bytes(2, fill: palette.orange)[Length = 0xFFFF], bits(12)[Flags],
)
