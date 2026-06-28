#import "@local/pivot:0.1.0": packet, bits, bytes

#set page(width: auto, height: auto, margin: 0.5cm)

// Narrow fields clustered against the left edge, each with a label far wider than
// its cell. A left/right split would run one field's drop through a neighbour's
// label, so the renderer falls back to a single right-aligned callout column
// outside the frame — crossing-free by construction.
#packet(
  bits(1)[Urgent], bits(1)[Acked], bits(1)[Pushed], bits(1)[Reset],
  bits(4)[Data offset],
  bytes(3)[Window size],
)
