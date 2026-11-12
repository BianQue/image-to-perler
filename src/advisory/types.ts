import type { Project } from '../core';

/**
 * The picture a compare group is judged against. It is the user's photo, or the picture the Agent regenerated in its place.
 * It is never the tone-preprocessed output. The structure measure ignores global tone on purpose.
 */
export interface BaseImage {
  width: number;
  height: number;
  /** sRGB, 4 bytes per pixel. Transparent pixels count as paper. The evaluator never reads more than a 256 px canvas. */
  rgba: Uint8ClampedArray;
}

export interface Candidate {
  /** Caller's key, echoed back. Unique within one screen() call. */
  id: string;
  project: Project;
}

/** What the caller can do about a flag. The evaluator names the lever and never pulls it. */
export type Lever = 'preprocess' | 'more-colours' | 'regenerate';

export type FlagCode = 'broken' | 'flat-collapse' | 'colour-shift';

/**
 * warn: the candidate is not recommended, and it folds while a clean one exists.
 * note: shown to the user, no effect on state.
 */
export interface Flag {
  code: FlagCode;
  severity: 'warn' | 'note';
  message: string;
  lever: Lever;
  /** The measured value and the limit it crossed, so a reader can check the number. */
  value: number;
  limit: number;
  /** Centre of the worst window in base-image coordinates, 0..1. Only for flat-collapse. */
  where?: { x: number; y: number };
}

/** recommended: smallest clean candidate near the best. folded: shown collapsed, still selectable. shown: everything else. */
export type AdvisoryState = 'recommended' | 'shown' | 'folded';

export interface CandidateReport {
  id: string;
  /** 0..100, 100 times the structure axis. A rank inside one group. It is not a pass mark and it does not compare across photos. */
  score: number;
  state: AdvisoryState;
  flags: Flag[];
  /** The raw numbers behind score and flags, read-only. */
  axes: { structure: number; detail: number; hueErrorDeg: number | null };
  /** Measured and shown, never scored. The accepted preprocessing recipe raises isolatedShare, so scoring it would punish the recipe. */
  info: { beads: number; colours: number; isolatedShare: number };
}

export interface Screening {
  /** Best score first. Ties break on fewer beads. Every input candidate appears exactly once. */
  reports: CandidateReport[];
  recommendedId: string | null;
  /** weak: no candidate is clean. Nothing is recommended and the best one is still shown. */
  group: 'ok' | 'weak';
  /** Literal true. Every threshold here is provisional, so a UI must not present the result as validated. */
  provisional: true;
}
