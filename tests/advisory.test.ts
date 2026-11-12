import { describe, expect, it } from 'vitest';
import { screen, type BaseImage, type Candidate } from '../src/advisory';
import { disc, gridOf, palette, shuffled } from './advisory-fixtures';

const photo = disc(128, 128, true), flatPhoto = disc(128, 128, false);
const cand = (id: string, project = gridOf(photo, 64)): Candidate => ({ id, project });
const byId = (s: ReturnType<typeof screen>, id: string) => s.reports.find(r => r.id === id)!;

describe('筛选器是提示而不是门槛', () => {
  it('暗部细节被压平的候选被标记并折叠，但仍可选', () => {
    const s = screen(photo, [cand('detail'), cand('flat', gridOf(flatPhoto, 64))]);
    const flat = byId(s, 'flat'), flag = flat.flags.find(f => f.code === 'flat-collapse')!;
    expect(flag.severity).toBe('warn');
    expect(flag.value).toBeLessThan(flag.limit);
    expect(flag.lever).toBe('preprocess');
    expect(Math.hypot(flag.where!.x - 0.6, flag.where!.y - 0.4)).toBeLessThan(1 / 6);
    expect(flat.state).toBe('folded');
    expect(byId(s, 'detail').flags.filter(f => f.severity === 'warn')).toEqual([]);
    expect(s.recommendedId).toBe('detail');
    expect(s.reports.map(r => r.id).sort()).toEqual(['detail', 'flat']);
  });

  it('打乱格子后结构分很低并被标为不可用', () => {
    const s = screen(photo, [cand('ok'), cand('shuffled', shuffled(gridOf(photo, 64)))]);
    const bad = byId(s, 'shuffled');
    expect(bad.score).toBeLessThan(30);
    expect(bad.flags.map(f => f.code)).toContain('broken');
    expect(bad.state).toBe('folded');
    expect(byId(s, 'ok').score).toBeGreaterThan(bad.score + 50);
    expect(bad.info.colours).toBe(byId(s, 'ok').info.colours);
  });

  it('尺寸阶梯分数随尺寸单调上升，推荐最佳分 10 分内豆数最少者', () => {
    const sizes = [32, 64, 96, 128], s = screen(photo, sizes.map(g => cand(`g${g}`, gridOf(photo, g))));
    const scores = sizes.map(g => byId(s, `g${g}`).score);
    expect([...scores].sort((a, b) => a - b)).toEqual(scores);
    expect(new Set(scores).size).toBe(sizes.length);
    expect(s.reports.map(r => r.id)).toEqual(['g128', 'g96', 'g64', 'g32']);
    expect(s.group).toBe('ok');
    expect(s.recommendedId).toBe('g96');
    expect(byId(s, 'g96').score).toBeGreaterThanOrEqual(byId(s, 'g128').score - 10);
    expect(byId(s, 'g64').score).toBeLessThan(byId(s, 'g128').score - 10);
    expect(s.reports.filter(r => r.state === 'recommended')).toHaveLength(1);
    expect(byId(s, 'g32').state).toBe('folded');
  });

  it('全部带警告时整组偏弱，不推荐任何一个，最好的仍然显示', () => {
    const s = screen(photo, [32, 64].map(g => cand(`flat${g}`, gridOf(flatPhoto, g))));
    expect(s.group).toBe('weak');
    expect(s.recommendedId).toBeNull();
    expect(s.reports.some(r => r.state === 'recommended')).toBe(false);
    expect(s.reports[0].state).toBe('shown');
    expect(s.reports.every(r => r.flags.some(f => f.severity === 'warn'))).toBe(true);
  });

  it('结果总是标明临时，空组也不抛错', () => {
    expect(screen(photo, [cand('a')]).provisional).toBe(true);
    const empty = screen(photo, []);
    expect(empty).toEqual({ reports: [], recommendedId: null, group: 'weak', provisional: true });
  });

  it('候选的分数不依赖同组还有谁，两轮合并与分开算一致', () => {
    const one = cand('x', gridOf(photo, 48)), other = cand('y', gridOf(photo, 128));
    const alone = byId(screen(photo, [one]), 'x'), grouped = byId(screen(photo, [other, one]), 'x');
    expect(grouped.score).toBe(alone.score);
    expect(grouped.axes).toEqual(alone.axes);
    expect(screen(photo, [one, other])).toEqual(screen(photo, [one, other]));
  });
});

describe('色相偏差只是提示', () => {
  it('色相差很大时给出提示，不影响推荐', () => {
    const swapped: BaseImage = { ...photo, rgba: photo.rgba.slice() };
    for (let i = 0; i < photo.width * photo.height; i++) swapped.rgba.set([photo.rgba[i * 4 + 2], photo.rgba[i * 4 + 1], photo.rgba[i * 4]], i * 4);
    const shifted = byId(screen(swapped, [cand('a')]), 'a'), plain = byId(screen(photo, [cand('a')]), 'a');
    const flag = shifted.flags.find(f => f.code === 'colour-shift')!;
    expect(flag.severity).toBe('note');
    expect(flag.lever).toBe('more-colours');
    expect(flag.value).toBeGreaterThan(flag.limit);
    expect(shifted.state).toBe('recommended');
    expect(plain.flags.map(f => f.code)).not.toContain('colour-shift');
  });
});

describe('空格与透明像素按纸色算', () => {
  it('背景格留空与填成近白色的分数几乎一样', () => {
    const filled = gridOf(photo, 64), ground = palette.colors[7].id;
    const emptied = { ...filled, cells: filled.cells.map(c => (c === ground ? null : c)) };
    const a = byId(screen(photo, [cand('filled', filled)]), 'filled'), b = byId(screen(photo, [cand('emptied', emptied)]), 'emptied');
    expect(Math.abs(a.score - b.score)).toBeLessThanOrEqual(2);
    expect(b.info.beads).toBeLessThan(a.info.beads);
  });

  it('透明的底稿像素与不透明白色等价', () => {
    const opaque = { ...photo, rgba: photo.rgba.slice() }, clear: BaseImage = { ...photo, rgba: photo.rgba.slice() };
    for (let i = 0; i < photo.width * photo.height; i++) if (photo.rgba[i * 4] === 0xF5 && photo.rgba[i * 4 + 1] === 0xF8) {
      opaque.rgba.set([255, 255, 255, 255], i * 4); clear.rgba.set([10, 200, 30, 0], i * 4);
    }
    const project = gridOf(photo, 64);
    expect(screen(clear, [cand('c', project)])).toEqual(screen(opaque, [cand('c', project)]));
  });
});

describe('输入边界', () => {
  it('候选标识重复、色号不在色板内、底稿尺寸不符时报错', () => {
    expect(() => screen(photo, [cand('a'), cand('a')])).toThrow('唯一');
    const broken = gridOf(photo, 16);
    expect(() => screen(photo, [cand('a', { ...broken, cells: broken.cells.map(() => 'nope:1') })])).toThrow('色板外');
    expect(() => screen({ ...photo, rgba: new Uint8ClampedArray(4) }, [cand('a')])).toThrow('底稿');
  });
});
