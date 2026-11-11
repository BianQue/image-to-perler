# Color Budget Product Research

Research date: 2026-11-11. Scope: whether a fixed 24-color limit is an appropriate default for Agent-assisted bead pattern creation.

## Observed Practices

- Pixel-Beads explicitly advises trying different color counts and selecting the best result while keeping the count low. It supports excluding individual palette colors, custom palettes, and replacing colors below a usage threshold. This supports comparison, not a universal numeric default.
  Source: https://www.pixel-beads.net/sites/instruction.html
- PixelBeads.io showcases examples with dimensions, actual color counts, and bead counts together, including simple three-color icons and more detailed portraits. These are examples rather than evidence of optimal defaults.
  Source: https://www.pixelbeads.io/
- Pixel Beads Art recommends adjusting size and color count with the preview, selecting the palette the user owns, and checking quantities before export. Its FAQ notes that fewer colors simplify a pattern but can remove shading.
  Source: https://www.pixel-beads.com/pixel-art-generator
- Make Pixel Bead presents Simple, Standard, High detail, and Custom options with widths. It separately exposes color detail and Clean versus Photo conversion styles; its public page shows a 14-color setting.
  Source: https://makepixelbead.com/create/image/

These are first-party product pages, not comparative usability studies. Public page defaults may differ from saved sessions or uploaded-image states. They establish available practices, not market leadership or proven optimal values.

## Proposed Design (Not Yet Accepted)

Use automatic color selection as the user-facing default. Treat 24 as an initial evaluation budget, not a hard limit or a claim of best practice.

Honor explicit user constraints first. For unconstrained work, evaluate a bounded set of size and color-budget combinations using the same source and brand palette. Prefer the smallest evaluated size passing the agreed quality rubric and critical-feature requirements; within that size prefer fewer colors that still pass. If a slightly larger alternative substantially reduces colors, expose that tradeoff rather than silently choosing it.

Present one recommendation and up to two meaningful alternatives. Show actual dimensions, occupied bead count, actual used colors, and short reasons. Distinguish the configured color cap from actual colors used. Avoid fabricated time or price estimates.

Low-frequency colors should be review candidates, not automatically disposable: a small eye highlight or identifying mark may be a required feature.

The existing 80/100 rubric is a project decision, not a scientifically validated threshold. Calibrate it against maintainer-reviewed examples before claiming reliable automatic recommendations. Candidate ranges and iteration limits remain open.

## Limits

No interactive conversion, user study, or runtime change was performed. Evidence does not establish a universal best color count, nor prove that adaptive search outperforms a fixed default for this project's users.
