#import "@local/pivot:0.1.0": bits, bytes, packet, palette

#set page(width: auto, height: auto, margin: 6pt)
#set text(font: "DejaVu Sans Mono")

// TCP header (RFC 793), including the sub-byte control-flag row. The sequence
// and acknowledgment numbers — what an off-path attacker must predict to inject
// or reset a connection — are highlighted.
#figure(
  packet(
    bytes(2)[Source Port], bytes(2)[Destination Port],
    bytes(4, fill: palette.blue)[Sequence Number],
    bytes(4, fill: palette.blue)[Acknowledgment Number],
    bits(4)[Data Offset], bits(6)[Reserved],
    bits(1)[URG], bits(1)[ACK], bits(1)[PSH], bits(1)[RST], bits(1)[SYN], bits(1)[FIN],
    bytes(2)[Window],
    bytes(2)[Checksum], bytes(2)[Urgent Pointer],
  ),
  caption: [A TCP header, sequence and acknowledgment numbers highlighted.],
)
