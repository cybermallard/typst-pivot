#import "@local/pivot:0.1.0": timeline, event, palette

#set page(width: auto, height: auto, margin: 0.5cm)

// A horizontal timeline: events spaced left-to-right along a rule, labels
// alternating above and below it. Shape and colour mark the NCSC attack-lifecycle
// stage (● blue survey  ■ purple delivery  ▲ green breach  ◆ red affect), so a
// stage reads as a run of matching markers. "Privilege escalation" is sparse — a
// title only, the way a draft reads before the detail is pinned down.
#timeline(
  event(time: "08:00", fill: palette.blue, description: [Shodan: exposed VPN appliance.])[Reconnaissance],
  event(time: "08:40", shape: "square", fill: palette.purple, description: [CVE-2024-3400 request sent.])[Exploit delivered],
  event(time: "08:42", shape: "triangle", fill: palette.green, description: [Exploit fires; web shell dropped.])[Initial access],
  event(time: "09:15", shape: "triangle", fill: palette.green)[Privilege escalation],
  event(time: "10:30", shape: "triangle", fill: palette.green, description: [Pivoted to the domain controller.])[Lateral movement],
  event(time: "13:48", shape: "diamond", fill: palette.vermillion, description: [Backup archives copied out.])[Exfiltration],
)
