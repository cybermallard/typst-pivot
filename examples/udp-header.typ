#import "@local/pivot:0.1.0": bytes, packet

#set page(width: auto, height: auto, margin: 6pt)
#set text(font: "DejaVu Sans Mono")

// UDP header (RFC 768): four 16-bit fields, two 32-bit rows.
#packet(
  bytes(2)[Source Port], bytes(2)[Destination Port],
  bytes(2)[Length], bytes(2)[Checksum],
)
