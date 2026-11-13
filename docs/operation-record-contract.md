# Project operation-record contract (S1-a)

Accepted design baseline, 2026-11-13 (UTC+8). This specifies future implementation requirements; no runtime implementation is included. Derived from [the accepted plan](reviews/2026-11-13-pr1-baseline/PLAN.md#s1-a范围与记录契约), [locked defaults](reviews/2026-11-13-pr1-baseline/DEFAULT-DECISIONS.md), and [shared record requirements](selective-undo-after-transform.md#实现必须共享的记录).

All Project mutation entry points must produce a record or an explicit “automatic recovery unsupported” barrier. Ordinary undo, redo, human strokes, and Agent compensation share this record model. Restoring old values must create new versions, not restore old versions. The ordinary 50-snapshot limit must not truncate collaboration history.

## Observed entry points

References below are line numbers in `src/main.ts` at pinned design head `bdc9c0adc8f0be4b329bf43b7babdae45693cae7`, not assertions that this baseline implements records. Inspect with:

```sh
git show bdc9c0adc8f0be4b329bf43b7babdae45693cae7:src/main.ts | nl -ba
```

| Entry / pinned line | Observed Project mutation | Required record coverage |
| --- | --- | --- |
| Startup, 9 and embedded Project load, 14 | Create initial Project or parse embedded JSON | Baseline snapshot and project identity; a filename is not collaboration identity |
| `commit`, 83; `install`, 88 | Shared replacement and history push; identical Project is a no-op | Transaction identity, before/after state and versions; classify installation by originating action |
| Selection fill/delete, 54–55 | Paint selected cells or clear them | Whole actual write set with paired color/completed before/after values |
| Despeckle, 57–64 | Remove isolated cells within selection | Actual writes and neighborhood/selection read dependencies |
| `apply`, 156–168 | Paint, erase, flood fill, replace color, toggle completed; selection masks writes | Paired cell values and versions; fill/replace read dependencies; pick is UI-only |
| 2D pointer stroke / Shift-line, 170–212; keyboard Space, 231 | Apply edits across one stroke | One intent and eventual record, distinguish temporary state from commit |
| Selection move, 189–199 | Clear source and overwrite destination including completed | Entire source and destination write set, before/after values; unsupported automatic recovery barrier until separately supported |
| `finishStroke`, 213–230; tool switch, 233 | Restore stroke start, then commit final preview; pointer up/cancel/lost capture finish it | One final record; preview must not claim durable success |
| Transform handler, 234 | Rotate / flipH / flipV after finishing stroke | Coordinate epoch, dimensions and forward map; structure transaction |
| Undo / redo, 235–236; shortcut dispatch, 286 | Replace Project directly from history, bypassing `commit` | New record/version for each action, with restored values and structural/field metadata |
| Name change, 237 | Validate and commit name | Field before/after value and field versions; no coordinate transform |
| Resize, 238 | Resize with right/bottom removal when shrinking | Dimensions, mapping, removed paired before-images and deletion conflicts; no arbitrary crop promise |
| New blank, 239 | Install newly created Project | Baseline/replacement record and identity boundary |
| Physical board size, 240 | Commit boardSize | Field before/after value and field versions; no coordinate transform |
| Map palette, 66–75 | Install mapped cells and palette, retaining completed | Full old/new palette and mapping including null, palette epoch; conservative recovery barrier |
| Open Project JSON, 258 | Parse and install Project | Replacement/baseline and identity checks; same filename does not resume history |
| Import image, 260–269 | Quantize candidate, assign its name, then install | Whole replacement transaction only after confirmation; capture name and Project before/after |
| Restore local draft, 271 | Parse localStorage draft and install | Replacement/baseline record; do not infer collaboration identity |
| 3D edit callback, 277–282 | `apply` / line and `finishStroke` | Same stroke contract as 2D, including start/move/end |

Palette-file import (259) changes the palette catalog/selection, not the current Project; only later mapping, new, or image installation changes Project. Selection-only gestures, view controls, exports, and draft serialization do not mutate Project. This distinction does not exempt any later Project-changing path from the contract.

## Minimum record contents

- Transaction: projectId, projectEpoch, opId, author, kind, baseRev, commitRev; inverseOf for compensation. Author and time must come from real provenance.
- Cell effects: actual write set, paired colorId/completed before and after, beforeVersion and afterVersion. New concurrent submissions still validate read dependencies and expected old values.
- Structure: coordinateEpoch, old/new dimensions, forward coordinate map and inverse domain; deleted coordinates explicitly have no target. Preserve deleted paired before-images and region/offset information.
- Palette: old/new palette contents or immutable versions, paletteEpoch, complete source-to-target color-ID map and null handling. Do not reconstruct mappings by approximate RGB or discard namespaces.
- Fields: name and boardSize before/after values and field versions, without falsely incrementing coordinate transforms.
- Recovery: accepted cells, conflicts and per-cell reasons, preview revision, independent compensationOpId and unresolved cells after partial recovery.
- Baseline/log: baseline snapshot, content hash, continuous operation prefix and version watermarks. Session metadata wraps Project v1; exported Project JSON alone does not restore collaboration history.

Q8 preserves committed concrete effects; it does not replay later conditional UI commands. Structural selective undo and palette recovery remain conservative barriers unless separately proved safe. Q4 requires RePreview for stale proposals and renewed explicit confirmation if results change; preview writes neither current Project nor persistent history.

S1-b through S1-d implement and verify the records; S2 checks in-memory semantics only. Durable success belongs to S3-d/S3-h. Q2 permits checkpoints without prefix deletion; Q3 permits conservative matching or rejection while retaining pending records, never automatic fast-forward or whole-backup replacement. These are requirements for later implementation, not acceptance of current runtime behavior.
