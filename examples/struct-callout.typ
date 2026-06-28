#import "@local/pivot:0.1.0": struct, bytes, palette

#set page(width: auto, height: auto, margin: 0.5cm)

// When a label is too long for even two wrapped lines, it drops to a leader
// callout centred BELOW the box (not the box itself), so the diagram stays
// centred. Width decides, not box height: the tall 8-byte box is still too
// narrow for this description.
#struct(
  bytes(4)[Magic],
  bytes(2)[Version],
  bytes(
    8,
    fill: palette.orange,
  )[Encrypted configuration block with per-campaign rotating key],
  bytes(4)[CRC-32 checksum],
)
