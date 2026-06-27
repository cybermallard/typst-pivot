#import "@local/pivot:0.1.0": bytes, packet

#set page(width: auto, height: auto, margin: 8pt)
#set text(font: "DejaVu Sans Mono")

// The UDP header with `ruler: "full"` — the opt-out from the default deduplicated
// ruler: every box edge is numbered on every row, repeats and all.
#packet(
  ruler: "full",
  bytes(2)[Source Port], bytes(2)[Destination Port],
  bytes(2)[Length], bytes(2)[Checksum],
)
