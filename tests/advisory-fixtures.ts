import type { Palette, Project } from '../src/core';
import type { BaseImage } from '../src/advisory';

const hexes = ['#141C30', '#323E5C', '#506082', '#6E82A5', '#8CA2C3', '#AFC3DC', '#D2E1F0', '#F5F8FC', '#B03030', '#E08040', '#40A060', '#E0C040'];
export const palette: Palette = { id: 'fx', name: '过程图色板', colors: hexes.map((hex, i) => ({ id: `fx:${i}`, name: `c${i}`, hex })) };

const rgb = (hex: string) => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));

/**
 * Integer-only procedural photo built from palette colours: a banded disc with a diagonal texture on a light ground.
 * With `detail` it also has a dark spot inside a bright ring, the kind of feature a coarse quantizer flattens.
 */
export function disc(width: number, height: number, detail: boolean): BaseImage {
  const rgba = new Uint8ClampedArray(width * height * 4), stripe = width >> 3, unit = Math.min(width, height);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const dx = 2 * x + 1 - width, dy = 2 * y + 1 - height;
    let colour = 7;
    if (dx * dx * height * height + dy * dy * width * width < 0.64 * width * width * height * height) {
      const band = 2 + Math.floor(((x + y) * 3) / (width + height)), odd = Math.floor((x - y + width) / stripe) & 1;
      colour = band + odd;
      const ex = x - Math.floor(width * 0.6), ey = y - Math.floor(height * 0.4), e2 = ex * ex + ey * ey, r = unit / 12;
      if (detail && e2 < 4 * r * r) colour = e2 < r * r ? 0 : 7;
    }
    const o = (y * width + x) * 4, [cr, cg, cb] = rgb(hexes[colour]);
    rgba[o] = cr; rgba[o + 1] = cg; rgba[o + 2] = cb; rgba[o + 3] = 255;
  }
  return { width, height, rgba };
}

/** Nearest palette colour, by integer squared RGB distance, at each cell's centre pixel. The grid keeps the base aspect. */
export function gridOf(base: BaseImage, gridWidth: number): Project {
  const gridHeight = Math.round((gridWidth * base.height) / base.width), pal = palette.colors.map(c => rgb(c.hex)), cells: (string | null)[] = [];
  for (let gy = 0; gy < gridHeight; gy++) for (let gx = 0; gx < gridWidth; gx++) {
    const px = Math.floor(((2 * gx + 1) * base.width) / (2 * gridWidth)), py = Math.floor(((2 * gy + 1) * base.height) / (2 * gridHeight)), o = (py * base.width + px) * 4;
    let best = 0, bd = Infinity;
    pal.forEach((p, i) => { const d = (p[0] - base.rgba[o]) ** 2 + (p[1] - base.rgba[o + 1]) ** 2 + (p[2] - base.rgba[o + 2]) ** 2; if (d < bd) { bd = d; best = i; } });
    cells.push(palette.colors[best].id);
  }
  return { version: 1, name: 'fx', width: gridWidth, height: gridHeight, boardSize: 29, palette, cells, completed: Array(cells.length).fill(false) };
}

/** Same cells in a deterministic scramble. Same colours and counts, no structure. */
export function shuffled(p: Project): Project {
  const n = p.cells.length, step = 7919;
  return { ...p, cells: p.cells.map((_, i) => p.cells[(i * step + 13) % n]) };
}
