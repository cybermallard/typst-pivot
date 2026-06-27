#import "@local/pivot:0.1.0": bits, bytes, packet

#set page(width: auto, height: auto, margin: 6pt)
#set text(font: "DejaVu Sans Mono")

// TCP header (RFC 793), including the sub-byte control-flag row.
#packet(
  bytes(2)[Source Port], bytes(2)[Destination Port],
  bytes(4)[Sequence Number],
  bytes(4)[Acknowledgment Number],
  bits(4)[Data Offset], bits(6)[Reserved],
  bits(1)[URG], bits(1)[ACK], bits(1)[PSH], bits(1)[RST], bits(1)[SYN], bits(1)[FIN],
  bytes(2)[Window],
  bytes(2)[Checksum], bytes(2)[Urgent Pointer],
)
