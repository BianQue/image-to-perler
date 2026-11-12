import { describe, expect, it } from 'vitest';
import { screen } from '../src/advisory';
import { PARITY_CASES } from './advisory-parity-cases';
import reference from './advisory-reference.json';

type Ref = { structure: number; detail: number; hueErrorDeg: number | null; where: { x: number; y: number } };
const refs = reference as Record<string, Ref>;

describe('与 numpy 参考实现一致', () => {
  it.each(PARITY_CASES.map(c => [c.name, c] as const))('%s', (name, c) => {
    const { base, project } = c.build();
    const r = screen(base, [{ id: name, project }]).reports[0], ref = refs[name];
    expect(Math.abs(r.axes.structure - ref.structure)).toBeLessThan(1e-3);
    expect(Math.abs(r.axes.detail - ref.detail)).toBeLessThan(1e-3);
    if (ref.hueErrorDeg === null) expect(r.axes.hueErrorDeg).toBeNull();
    else expect(Math.abs(r.axes.hueErrorDeg! - ref.hueErrorDeg)).toBeLessThan(1e-3);
    if (name.includes('flattened')) {
      const where = r.flags.find(f => f.code === 'flat-collapse')!.where!;
      // The worst window sits on a near-flat minimum, so float32 noise moves the argmin by a few canvas pixels. 0.03 is under one window radius.
      expect(Math.hypot(where.x - ref.where.x, where.y - ref.where.y)).toBeLessThan(0.03);
    }
  });
});
