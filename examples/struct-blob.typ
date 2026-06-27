#import "@local/pivot:0.1.0": bytes, palette, struct

#set page(width: auto, height: auto, margin: 8pt)
#set text(font: "DejaVu Sans Mono")

// A packed payload with a large encrypted blob. The blob is far taller than the
// height cap, so it's drawn short with a torn "break mark" bottom edge — the size
// label (512 B) still tells the truth.
#struct(
  bytes(4)[Magic],
  bytes(2)[Version], bytes(2)[Flags],
  bytes(512, fill: palette.orange)[Encrypted Payload],
  bytes(4)[CRC32],
)
