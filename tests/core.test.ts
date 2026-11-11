import { describe, expect, it } from 'vitest';
import { createProject, exportCsv, floodFill, paint, parsePalette, parseProject, quantize, replaceColor, resizeProject, serializeProject, transform, usage, validateProject, type Palette } from '../src/core';
import { palettes } from '../src/palettes';

const palette: Palette = { id: 'test', name: '测试', colors: [
  { id: 'test:white', name: '白', hex: '#FFFFFF' },
  { id: 'test:black', name: '黑', hex: '#000000' },
  { id: 'test:red', name: '红', hex: '#FF0000' },
] };
const white = 'test:white', black = 'test:black', red = 'test:red';

describe('项目和色板边界', () => {
  it('保存重开保留色板身份、尺寸与进度，结果不共享数组', () => {
    const p = paint(createProject(3, 2, palette, '图纸'), [0, 2], white);
    p.completed[2] = true;
    const restored = parseProject(serializeProject(p));
    expect(restored).toEqual(p);
    expect(restored.cells).not.toBe(p.cells);
    expect(restored.palette).not.toBe(p.palette);
  });
  it('所有内置色板有唯一命名空间且可导入', () => {
    expect(palettes).toHaveLength(12);
    const ids = palettes.flatMap(p => p.colors.map(c => c.id));
    expect(new Set(ids).size).toBe(ids.length);
    for (const p of palettes) expect(parsePalette(JSON.stringify(p))).toEqual(p);
  });
  it('拒绝无效尺寸、版本、未知色号、非布尔进度和数组空洞', () => {
    const p = createProject(2, 2, palette);
    for (const width of [0, 257, 1.5, NaN, Infinity]) expect(() => createProject(width, 2, palette)).toThrow();
    for (const patch of [{ version: 2 }, { cells: [] }, { cells: ['missing', null, null, null] }, { completed: [1, false, false, false] }, { cells: Array(4) }, { completed: [true, false, false, false] }]) expect(() => validateProject({ ...p, ...patch })).toThrow();
    expect(() => parseProject('{')).toThrow();
  });
  it('拒绝空色板、重复色号、错误前缀与非法HEX', () => {
    for (const colors of [[], [palette.colors[0], palette.colors[0]], [{ ...palette.colors[0], id: 'white' }], [{ ...palette.colors[0], hex: 'white' }]]) expect(() => parsePalette(JSON.stringify({ ...palette, colors }))).toThrow();
  });
});

describe('不可变编辑', () => {
  it('白色保留为珠子，擦除产生空格，颜色变化重置进度', () => {
    const original = createProject(2, 1, palette);
    const p = paint(original, [0], white); p.completed[0] = true;
    expect(original.cells).toEqual([null, null]);
    expect(paint(p, [0], white).completed[0]).toBe(true);
    expect(paint(p, [0], black).completed[0]).toBe(false);
    expect(paint(p, [0], null).cells).toEqual([null, null]);
    expect(p.cells).toEqual([white, null]);
    expect(usage(p)).toEqual([{ color: palette.colors[0], count: 1 }]);
  });
  it('填充只连接四邻域且不跨行', () => {
    const p = paint(createProject(3, 3, palette), [1, 4, 7], black);
    expect(floodFill(p, 0, white).cells).toEqual([white, black, null, white, black, null, white, black, null]);
    expect(floodFill(p, 2, red).cells).toEqual([null, black, red, null, black, red, null, black, red]);
    expect(floodFill(p, 1, black)).toEqual(p);
    expect(p.cells[0]).toBe(null);
  });
  it('替换颜色更新所有匹配格及对应进度', () => {
    const p = paint(createProject(3, 1, palette), [0, 2], white); p.completed[0] = true;
    const replaced = replaceColor(p, white, red);
    expect(replaced.cells).toEqual([red, null, red]);
    expect(replaced.completed).toEqual([false, false, false]);
    expect(p.completed[0]).toBe(true);
  });
  it('矩形旋转和翻转携带进度，四次旋转恢复原图', () => {
    const p = createProject(3, 2, palette); p.cells = [white, black, red, null, white, black]; p.completed[0] = true;
    const rotated = transform(p, 'rotate');
    expect([rotated.width, rotated.height]).toEqual([2, 3]);
    expect(rotated.cells).toEqual([null, white, white, black, black, red]);
    expect(rotated.completed).toEqual([false, true, false, false, false, false]);
    expect(transform(transform(transform(rotated, 'rotate'), 'rotate'), 'rotate')).toEqual(p);
    expect(transform(p, 'flipH').cells).toEqual([red, black, white, black, white, null]);
    expect(transform(p, 'flipV').cells).toEqual([null, white, black, white, black, red]);
    expect(transform(transform(p, 'flipH'), 'flipH')).toEqual(p);
  });
  it('缩放画布保留左上区域并为新增格补空', () => {
    const p = paint(createProject(2, 2, palette), [0, 3], red); p.completed[3] = true;
    const grown = resizeProject(p, 3, 3);
    expect(grown.cells).toEqual([red, null, null, null, red, null, null, null, null]);
    expect(grown.completed[4]).toBe(true);
    expect(resizeProject(grown, 2, 2)).toEqual(p);
    expect(resizeProject(p, 1, 1).cells).toEqual([red]);
  });
  it('拒绝越界坐标和未知颜色', () => {
    const p = createProject(2, 2, palette);
    expect(() => paint(p, [-1], white)).toThrow();
    expect(() => paint(p, [4], white)).toThrow();
    expect(() => floodFill(p, 1.2, white)).toThrow();
    expect(() => replaceColor(p, null, 'other:white')).toThrow();
  });
});

describe('量化与用量', () => {
  it('透明阈值为128，纯白不会被删除', () => {
    const p = quantize(new Uint8ClampedArray([255, 255, 255, 255, 0, 0, 0, 127, 255, 0, 0, 128]), 3, 1, palette, 3);
    expect(p.cells).toEqual([white, null, red]);
    expect(usage(p).reduce((n, u) => n + u.count, 0)).toBe(2);
  });
  it('色数受限、输出确定、全透明图片保持空白', () => {
    const rgba = new Uint8ClampedArray([255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255, 255]);
    const p = quantize(rgba, 4, 1, palette, 1);
    expect(p.cells).toEqual([red, red, red, red]);
    expect(quantize(rgba, 4, 1, palette, 1)).toEqual(p);
    expect(quantize(new Uint8ClampedArray(16), 4, 1, palette, 1).cells).toEqual([null, null, null, null]);
    expect(() => quantize(rgba, 2, 1, palette, 1)).toThrow();
    expect(() => quantize(rgba, 4, 1, palette, 0)).toThrow();
  });
  it('CSV按用量导出并防护公式字段', () => {
    const custom = { ...palette, name: '=bad', colors: palette.colors.map(c => ({ ...c, name: 'a,"b' })) };
    const p = paint(createProject(3, 1, custom), [0, 2], white);
    expect(exportCsv(p)).toContain('"\'=bad","test:white","a,""b","#FFFFFF","2"');
    expect(exportCsv(p)).not.toContain('test:black');
  });
});
