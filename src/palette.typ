// palette: the shared Okabe–Ito colour-blind-safe qualitative palette, lightened
// into highlight backgrounds that keep black text legible. One source of truth
// for field-highlight colour — `hexdump` cycles it for auto-colouring, and
// packet/struct fields reach for it in an explicit `fill:`. Pure; no cetz.
//
// `.values()` gives the cycle order (orange first); reach for a colour by name
// in a fill, e.g. `fill: palette.orange`.

#let palette = (
  orange: rgb("#E69F00").lighten(45%),
  sky: rgb("#56B4E9").lighten(45%),
  green: rgb("#009E73").lighten(45%),
  yellow: rgb("#F0E442").lighten(45%),
  blue: rgb("#0072B2").lighten(45%),
  vermillion: rgb("#D55E00").lighten(45%),
  purple: rgb("#CC79A7").lighten(45%),
  grey: rgb("#000000").lighten(80%),
)
