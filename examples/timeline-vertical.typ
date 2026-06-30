#import "@local/pivot:0.1.0": timeline, event, palette

#set page(width: auto, height: auto, margin: 0.5cm)

// A vertical timeline: events run top-to-bottom down a rule, labels alternating
// right and left. Good when a page is taller than it is wide. Shape and colour
// mark the NCSC attack-lifecycle stage (● blue survey  ■ purple delivery
// ▲ green breach  ◆ red affect) — here a web-app breach from probe to exfiltration.
#timeline(
  orientation: "vertical",
  event(time: "13:10", fill: palette.blue, description: [Login form mapped and fuzzed.])[Reconnaissance],
  event(time: "13:20", shape: "square", fill: palette.purple, description: [SQLi payload submitted.])[Injection],
  event(time: "13:34", shape: "triangle", fill: palette.green, description: [Authentication bypassed.])[Initial access],
  event(time: "13:51", shape: "triangle", fill: palette.green, description: [Web shell dropped to /uploads.])[Foothold],
  event(time: "14:38", shape: "diamond", fill: palette.vermillion, description: [Customer table dumped over DNS.])[Exfiltration],
)
