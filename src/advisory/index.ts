import { baseCanvas, candidateCells, measure, type Axes } from './measure';
import type { AdvisoryState, BaseImage, Candidate, CandidateReport, Flag, FlagCode, Lever, Screening } from './types';
export type * from './types';

/** Provisional gaps in score points. Neither is a validated default. */
const RECOMMEND_GAP = 10;
const FOLD_GAP = 15;

interface Test { severity: 'warn' | 'note'; limit: number }
interface FlagRule { lever: Lever; test(a: Axes): Test | null; value(a: Axes): number; message(value: number, limit: number): string }

/** The one table behind every flag. Thresholds were set on two private photos. */
const FLAGS: Record<FlagCode, FlagRule> = {
  broken: {
    lever: 'regenerate',
    value: a => a.structure,
    test: a => (a.structure < 0.30 ? { severity: 'warn', limit: 0.30 } : null),
    message: (v, l) => `图纸与底稿的明暗结构几乎对不上（${v.toFixed(2)}，下限 ${l}）。`,
  },
  'flat-collapse': {
    lever: 'preprocess',
    value: a => a.detail,
    test: a => (a.detail < 0.52 ? { severity: 'warn', limit: 0.52 } : a.detail < 0.75 ? { severity: 'note', limit: 0.75 } : null),
    message: (v, l) => `底稿里有细节的地方被压成了一块（保留比 ${v.toFixed(2)}，限值 ${l}）。`,
  },
  'colour-shift': {
    lever: 'more-colours',
    value: a => a.hueErrorDeg ?? 0,
    test: a => (a.hueErrorDeg !== null && a.hueErrorDeg > 35 ? { severity: 'note', limit: 35 } : null),
    message: (v, l) => `整体色相偏差较大（${v.toFixed(0)} 度，限值 ${l} 度）。`,
  },
};

function flagsOf(a: Axes): Flag[] {
  const out: Flag[] = [];
  for (const code of Object.keys(FLAGS) as FlagCode[]) {
    const rule = FLAGS[code], t = rule.test(a);
    if (!t) continue;
    const value = rule.value(a);
    out.push({ code, severity: t.severity, message: rule.message(value, t.limit), lever: rule.lever, value, limit: t.limit, ...(code === 'flat-collapse' ? { where: a.where } : {}) });
  }
  return out;
}

function isolatedShare(c: Candidate): { beads: number; colours: number; isolatedShare: number } {
  const { width: w, height: h, cells } = c.project, colours = new Set<string>();
  let beads = 0, isolated = 0;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const v = cells[y * w + x];
    if (v === null) continue;
    beads++; colours.add(v);
    if (!((x > 0 && cells[y * w + x - 1] === v) || (x + 1 < w && cells[y * w + x + 1] === v) || (y > 0 && cells[(y - 1) * w + x] === v) || (y + 1 < h && cells[(y + 1) * w + x] === v))) isolated++;
  }
  return { beads, colours: colours.size, isolatedShare: beads ? isolated / beads : 0 };
}

const hasWarn = (flags: Flag[]) => flags.some(f => f.severity === 'warn');

/**
 * Always runs, ranks, flags and folds the clearly bad. It never blocks. The caller can pick any candidate whatever its state.
 *
 * One compare group means one base image and one palette.
 *   clean       = no warn flag.
 *   recommended = the fewest-bead candidate among clean ones within RECOMMEND_GAP of the best clean score.
 *   folded      = broken, or warned while a clean candidate exists, or more than FOLD_GAP under the best.
 *   weak group  = no clean candidate. Nothing is recommended, and the best candidate stays shown.
 *
 * Pure. Screening the union of two search rounds gives the same answer as one call with everything.
 */
export function screen(base: BaseImage, candidates: readonly Candidate[]): Screening {
  if (!(base.rgba instanceof Uint8ClampedArray) || base.rgba.length !== base.width * base.height * 4 || base.width < 1 || base.height < 1) throw new Error('底稿像素数量不匹配');
  if (new Set(candidates.map(c => c.id)).size !== candidates.length) throw new Error('候选标识必须唯一');
  const rows = candidates.map(c => {
    const axes = measure(baseCanvas(base, c.project), candidateCells(c));
    return { id: c.id, score: Math.max(0, Math.min(100, Math.round(100 * axes.structure))), flags: flagsOf(axes), axes, info: isolatedShare(c) };
  }).sort((a, b) => b.score - a.score || a.info.beads - b.info.beads);

  const clean = rows.filter(r => !hasWarn(r.flags));
  const best = (clean[0] ?? rows[0])?.score ?? 0;
  const recommended = clean
    .filter(r => r.score >= best - RECOMMEND_GAP)
    .sort((a, b) => a.info.beads - b.info.beads || a.flags.length - b.flags.length || b.score - a.score)[0];

  const reports = rows.map((r): CandidateReport => {
    const state: AdvisoryState = r === recommended ? 'recommended'
      : r.flags.some(f => f.code === 'broken') || (clean.length > 0 && !clean.includes(r)) || r.score < best - FOLD_GAP ? 'folded' : 'shown';
    const { structure, detail, hueErrorDeg } = r.axes;
    return { id: r.id, score: r.score, state, flags: r.flags, axes: { structure, detail, hueErrorDeg }, info: r.info };
  });
  return { reports, recommendedId: recommended?.id ?? null, group: clean.length ? 'ok' : 'weak', provisional: true };
}
