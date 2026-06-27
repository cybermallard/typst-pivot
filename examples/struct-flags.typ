#import "@local/pivot:0.1.0": bytes, bits, struct

#set page(width: auto, height: auto, margin: 8pt)
#set text(font: "DejaVu Sans Mono")

// A malware config header whose byte at 0x04 is carved into bit-flags. This is
// the case bit-field expansion exists for: the eight bits are one byte, not
// eight stacked rows.
#struct(
  bytes(4)[Config Magic],
  bits(1)[Anti-Debug], bits(1)[Persist], bits(1)[Encrypted C2], bits(1)[Anti-VM],
  bits(1)[Anti-Sandbox], bits(1)[Keylog], bits(2)[Reserved],
  bytes(2)[C2 Port],
)
