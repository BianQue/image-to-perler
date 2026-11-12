import type { BaseImage, Candidate } from './types';

/** Every constant is provisional. They were set on two private cat photos and are not validated. */
export const LIMITS = {
  canvas: 256, structureSigma: 3, windowFrac: 0.10, windowQuantile: 0.5, detailPercentile: 0.10,
  hueMinChroma: 0.05, hueMinCells: 20,
} as const;

export interface Axes { structure: number; detail: number; hueErrorDeg: number | null; where: { x: number; y: number } }

const lut = new Float32Array(256);
for (let i = 0; i < 256; i++) { const c = i / 255; lut[i] = c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; }

export function oklab(r: number, g: number, b: number, out: Float32Array, o: number): void {
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  out[o] = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
  out[o + 1] = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  out[o + 2] = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
}

export function hexToOklab(hex: string, out: Float32Array, o: number): void {
  oklab(lut[parseInt(hex.slice(1, 3), 16)], lut[parseInt(hex.slice(3, 5), 16)], lut[parseInt(hex.slice(5, 7), 16)], out, o);
}

function areaWeights(src: number, dst: number): { starts: Int32Array; w: number[][] } {
  const scale = src / dst, starts = new Int32Array(dst), w: number[][] = [];
  for (let i = 0; i < dst; i++) {
    const a = i * scale, b = (i + 1) * scale, i0 = Math.floor(a), i1 = Math.min(src - 1, Math.ceil(b) - 1), ws: number[] = [];
    for (let j = i0; j <= i1; j++) ws.push((Math.min(b, j + 1) - Math.max(a, j)) / scale);
    starts[i] = i0; w.push(ws);
  }
  return { starts, w };
}

function areaResize(src: Float32Array, sw: number, sh: number, dw: number, dh: number): Float32Array {
  const hx = areaWeights(sw, dw), tmp = new Float32Array(dw * sh * 3);
  for (let y = 0; y < sh; y++) for (let x = 0; x < dw; x++) {
    let r = 0, g = 0, b = 0; const ws = hx.w[x], s0 = hx.starts[x];
    for (let k = 0; k < ws.length; k++) { const p = (y * sw + s0 + k) * 3; r += src[p] * ws[k]; g += src[p + 1] * ws[k]; b += src[p + 2] * ws[k]; }
    const o = (y * dw + x) * 3; tmp[o] = r; tmp[o + 1] = g; tmp[o + 2] = b;
  }
  const vy = areaWeights(sh, dh), out = new Float32Array(dw * dh * 3);
  for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
    let r = 0, g = 0, b = 0; const ws = vy.w[y], s0 = vy.starts[y];
    for (let k = 0; k < ws.length; k++) { const p = ((s0 + k) * dw + x) * 3; r += tmp[p] * ws[k]; g += tmp[p + 1] * ws[k]; b += tmp[p + 2] * ws[k]; }
    const o = (y * dw + x) * 3; out[o] = r; out[o + 1] = g; out[o + 2] = b;
  }
  return out;
}

function reflect(i: number, n: number): number { if (i < 0) i = -i; if (i >= n) i = 2 * n - 2 - i; return i < 0 ? 0 : i; }

function blur(a: Float32Array, w: number, h: number, sigma: number): Float32Array {
  const r = Math.round(4 * sigma), k = new Float64Array(r + 1);
  let total = 0;
  for (let i = -r; i <= r; i++) total += Math.exp(-(i * i) / (2 * sigma * sigma));
  for (let i = 0; i <= r; i++) k[i] = Math.exp(-(i * i) / (2 * sigma * sigma)) / total;
  const tmp = new Float32Array(w * h), out = new Float32Array(w * h), acc = new Float64Array(w);
  for (let y = 0; y < h; y++) {
    const row = y * w;
    for (let x = 0; x < w; x++) {
      let s = a[row + x] * k[0];
      if (x >= r && x < w - r) for (let j = 1; j <= r; j++) s += k[j] * (a[row + x - j] + a[row + x + j]);
      else for (let j = 1; j <= r; j++) s += k[j] * (a[row + reflect(x - j, w)] + a[row + reflect(x + j, w)]);
      tmp[row + x] = s;
    }
  }
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) acc[x] = tmp[y * w + x] * k[0];
    for (let j = 1; j <= r; j++) {
      const up = reflect(y - j, h) * w, down = reflect(y + j, h) * w, kj = k[j];
      for (let x = 0; x < w; x++) acc[x] += kj * (tmp[up + x] + tmp[down + x]);
    }
    for (let x = 0; x < w; x++) out[y * w + x] = acc[x];
  }
  return out;
}

function quantile(values: ArrayLike<number>, q: number): number {
  const a = Float32Array.from(values).sort(), pos = q * (a.length - 1), lo = Math.floor(pos), hi = Math.ceil(pos);
  return a[lo] + (a[hi] - a[lo]) * (pos - lo);
}

export interface Canvas { w: number; h: number; lab: Float32Array }

/** Linear-light area average to the viewing canvas, then OKLab. Transparent pixels blend toward paper (white). */
export function baseCanvas(base: BaseImage, grid: { width: number; height: number }): Canvas {
  const k = LIMITS.canvas / Math.max(grid.width, grid.height), w = Math.round(grid.width * k), h = Math.round(grid.height * k);
  const n = base.width * base.height, lin = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) {
    const alpha = base.rgba[i * 4 + 3] / 255;
    for (let c = 0; c < 3; c++) lin[i * 3 + c] = lut[base.rgba[i * 4 + c]] * alpha + (1 - alpha);
  }
  const r = areaResize(lin, base.width, base.height, w, h), lab = new Float32Array(w * h * 3);
  for (let i = 0; i < w * h; i++) oklab(r[i * 3], r[i * 3 + 1], r[i * 3 + 2], lab, i * 3);
  return { w, h, lab };
}

/** One OKLab triple per cell. Empty cells hold paper. */
export interface CellLab { width: number; height: number; lab: Float32Array }

export function candidateCells(c: Candidate): CellLab {
  const { project } = c, paper = new Float32Array(3), byId = new Map<string, Float32Array>();
  oklab(1, 1, 1, paper, 0);
  for (const color of project.palette.colors) { const v = new Float32Array(3); hexToOklab(color.hex, v, 0); byId.set(color.id, v); }
  const lab = new Float32Array(project.width * project.height * 3);
  project.cells.forEach((id, i) => {
    const v = id === null ? paper : byId.get(id);
    if (!v) throw new Error(`候选 ${c.id} 含色板外的色号 ${id}`);
    lab.set(v, i * 3);
  });
  return { width: project.width, height: project.height, lab };
}

export function measure(cv: Canvas, cells: CellLab): Axes {
  const { w, h } = cv, n = w * h, cand = new Float32Array(n * 3);
  for (let y = 0; y < h; y++) {
    const cy = Math.min(cells.height - 1, Math.floor((y + 0.5) * cells.height / h));
    for (let x = 0; x < w; x++) {
      const cx = Math.min(cells.width - 1, Math.floor((x + 0.5) * cells.width / w)), s = (cy * cells.width + cx) * 3, o = (y * w + x) * 3;
      cand[o] = cells.lab[s]; cand[o + 1] = cells.lab[s + 1]; cand[o + 2] = cells.lab[s + 2];
    }
  }
  const A = new Float32Array(n), B = new Float32Array(n);
  for (let i = 0; i < n; i++) { A[i] = cv.lab[i * 3]; B[i] = cand[i * 3]; }
  const AA = A.map(v => v * v), BB = B.map(v => v * v), AB = A.map((v, i) => v * B[i]);
  const stats = (s: number) => ({ ma: blur(A, w, h, s), mb: blur(B, w, h, s), maa: blur(AA, w, h, s), mbb: blur(BB, w, h, s), mab: blur(AB, w, h, s) });

  const s1 = stats(LIMITS.structureSigma), c2 = 0.03 ** 2;
  let structure = 0;
  for (let i = 0; i < n; i++) {
    const va = s1.maa[i] - s1.ma[i] ** 2, vb = s1.mbb[i] - s1.mb[i] ** 2, cab = s1.mab[i] - s1.ma[i] * s1.mb[i];
    structure += (2 * cab + c2) / (va + vb + c2);
  }

  const s2 = stats(Math.max(2, Math.floor(LIMITS.windowFrac * Math.max(w, h) / 2.5)));
  const va = new Float32Array(n), vb = new Float32Array(n);
  for (let i = 0; i < n; i++) { va[i] = Math.max(s2.maa[i] - s2.ma[i] ** 2, 0); vb[i] = Math.max(s2.mbb[i] - s2.mb[i] ** 2, 0); }
  const cut = quantile(va, LIMITS.windowQuantile), ratios: number[] = [];
  let worst = Infinity, worstAt = 0;
  for (let i = 0; i < n; i++) if (va[i] >= cut) {
    const r = Math.min(vb[i] / (va[i] + 1e-6), 1);
    ratios.push(r);
    if (r < worst) { worst = r; worstAt = i; }
  }

  let hueSum = 0, chromaSum = 0, hueCells = 0;
  for (let i = 0; i < n; i++) {
    const a1 = cv.lab[i * 3 + 1], b1 = cv.lab[i * 3 + 2], chroma = Math.hypot(a1, b1);
    if (chroma <= LIMITS.hueMinChroma) continue;
    let d = Math.abs(Math.atan2(b1, a1) * 180 / Math.PI - Math.atan2(cand[i * 3 + 2], cand[i * 3 + 1]) * 180 / Math.PI);
    d = Math.abs(((d + 180) % 360) - 180);
    hueSum += d * chroma; chromaSum += chroma; hueCells++;
  }
  return {
    structure: structure / n,
    detail: quantile(ratios, LIMITS.detailPercentile),
    where: { x: ((worstAt % w) + 0.5) / w, y: (Math.floor(worstAt / w) + 0.5) / h },
    hueErrorDeg: hueCells >= LIMITS.hueMinCells ? hueSum / chromaSum : null,
  };
}
