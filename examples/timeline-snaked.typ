#import "@local/pivot:0.1.0": timeline, event, palette

#set page(width: auto, height: auto, margin: 0.5cm)

// A snaked timeline: rows wrap (`wrap` events each) and reverse direction, joined
// by curved U-bends — for a long sequence that would overflow one horizontal rule.
// Shape and colour mark the NCSC attack-lifecycle stage, so each reads as a block:
//   ● blue survey   ■ purple delivery   ▲ green breach   ◆ red affect
// A snake is an overview, so labels stay terse.
#timeline(
  orientation: "snaked",
  wrap: 4,
  event(time: "Day 1", fill: palette.blue, description: [Staff harvested via OSINT.])[Reconnaissance],
  event(time: "Day 1", fill: palette.blue, description: [Exposed VPN enumerated.])[Target scan],
  event(time: "Day 2", shape: "square", fill: palette.purple, description: [Macro doc to 8 staff.])[Phishing email],
  event(time: "Day 2", shape: "triangle", fill: palette.green, description: [Macro loader runs.])[Initial access],
  event(time: "Day 2", shape: "triangle", fill: palette.green, description: [Cobalt Strike beacon.])[C2 established],
  event(time: "Day 3", shape: "triangle", fill: palette.green, description: [Token theft to SYSTEM.])[Privilege escalation],
  event(time: "Day 3", shape: "triangle", fill: palette.green, description: [LSASS via Mimikatz.])[Credential access],
  event(time: "Day 4", shape: "triangle", fill: palette.green, description: [RDP via stolen creds.])[Lateral movement],
  event(time: "Day 7", shape: "diamond", fill: palette.vermillion, description: [12 GB to MEGA.])[Exfiltration],
  event(time: "Day 8", shape: "diamond", fill: palette.vermillion, description: [LockBit detonation.])[Impact],
)
