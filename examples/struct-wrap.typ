#import "@local/pivot:0.1.0": struct, bytes, palette

#set page(width: auto, height: auto, margin: 0.5cm)

// A label too wide for one line wraps to (up to) two lines inside the box,
// staying centred — the diagram keeps its width and the offset column its place.
#struct(
  bytes(4)[Magic],
  bytes(2)[Version],
  bytes(8, fill: palette.orange)[Encrypted configuration block],
  bytes(4)[CRC-32 checksum],
)
