import type { Project } from '../src/core';
import type { BaseImage } from '../src/advisory';
import { disc, gridOf, palette, shuffled } from './advisory-fixtures';

export interface ParityCase { name: string; build(): { base: BaseImage; project: Project } }

const square = disc(128, 128, true), wide = disc(160, 96, true), flatSquare = disc(128, 128, false);
const ground = palette.colors[7].id;
const emptied = (p: Project): Project => ({ ...p, cells: p.cells.map(c => (c === ground ? null : c)) });

export const PARITY_CASES: ParityCase[] = [
  ...[16, 32, 64, 128].map(g => ({ name: `disc-detail-${g}`, build: () => ({ base: square, project: gridOf(square, g) }) })),
  ...[32, 64].map(g => ({ name: `disc-flattened-${g}`, build: () => ({ base: square, project: gridOf(flatSquare, g) }) })),
  { name: 'disc-shuffled-64', build: () => ({ base: square, project: shuffled(gridOf(square, 64)) }) },
  { name: 'wide-detail-48', build: () => ({ base: wide, project: gridOf(wide, 48) }) },
  { name: 'wide-detail-96', build: () => ({ base: wide, project: gridOf(wide, 96) }) },
  { name: 'disc-emptied-64', build: () => ({ base: square, project: emptied(gridOf(square, 64)) }) },
];
