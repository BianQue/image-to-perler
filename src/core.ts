export interface BeadColor { id: string; name: string; hex: string }
export interface Palette { id: string; name: string; colors: BeadColor[] }
export interface Project {
  version: 1;
  name: string;
  width: number;
  height: number;
  boardSize: number;
  palette: Palette;
  cells: (string | null)[];
  completed: boolean[];
}

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('需要 JSON 对象');
  return value as Record<string, unknown>;
}
function text(value: unknown, label: string): string {
  if (typeof value !== 'string' || !value.trim() || value.length > 200) throw new Error(`${label}无效`);
  return value;
}
function dimension(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 1 || value > 256) throw new Error('尺寸必须为 1 至 256 的整数');
  return value;
}
function validatePalette(value: unknown): Palette {
  const p = object(value);
  const id = text(p.id, '色板标识');
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(id)) throw new Error('色板标识仅允许字母、数字、下划线和短横线');
  const name = text(p.name, '色板名称');
  if (!Array.isArray(p.colors) || p.colors.length < 1 || p.colors.length > 4096) throw new Error('色板需含 1 至 4096 个颜色');
  const ids = new Set<string>();
  const colors = p.colors.map(value => {
    const c = object(value);
    const colorId = text(c.id, '色号');
    if (!colorId.startsWith(`${id}:`) || colorId.length === id.length + 1 || ids.has(colorId)) throw new Error('色号必须唯一且带色板前缀');
    ids.add(colorId);
    const name = text(c.name, '颜色名称');
    if (typeof c.hex !== 'string' || !/^#[0-9a-fA-F]{6}$/.test(c.hex)) throw new Error('颜色须为六位 HEX');
    return { id: colorId, name, hex: c.hex.toUpperCase() };
  });
  return { id, name, colors };
}
export function parsePalette(input: string): Palette { return validatePalette(JSON.parse(input)); }
export function createProject(width: number, height: number, palette: Palette, name = '未命名图纸'): Project {
  dimension(width); dimension(height);
  return { version: 1, name: text(name, '项目名称'), width, height, boardSize: 29,
    palette: validatePalette(palette), cells: Array(width * height).fill(null), completed: Array(width * height).fill(false) };
}
export function validateProject(value: unknown): Project {
  const p = object(value);
  if (p.version !== 1) throw new Error('不支持的项目版本');
  const width = dimension(p.width), height = dimension(p.height), boardSize = dimension(p.boardSize);
  const palette = validatePalette(p.palette);
  const valid = new Set(palette.colors.map(c => c.id));
  if (!Array.isArray(p.cells) || p.cells.length !== width * height || !Array.isArray(p.completed) || p.completed.length !== width * height) throw new Error('格子或进度数量不匹配');
  const cells: (string | null)[] = [];
  const completed: boolean[] = [];
  for (let i = 0; i < width * height; i++) {
    const cell = p.cells[i], done = p.completed[i];
    if (cell !== null && (typeof cell !== 'string' || !valid.has(cell))) throw new Error('未知色号');
    if (typeof done !== 'boolean' || (cell === null && done)) throw new Error('进度无效');
    cells.push(cell as string | null); completed.push(done);
  }
  return { version: 1, name: text(p.name, '项目名称'), width, height, boardSize, palette, cells, completed };
}
export function serializeProject(project: Project): string { return JSON.stringify(validateProject(project), null, 2); }
export function parseProject(input: string): Project { return validateProject(JSON.parse(input)); }
export function usage(project: Project): { color: BeadColor; count: number }[] {
  const counts = new Map<string, number>();
  for (const id of project.cells) if (id !== null) counts.set(id, (counts.get(id) ?? 0) + 1);
  return project.palette.colors.filter(c => counts.has(c.id)).map(color => ({ color, count: counts.get(color.id)! })).sort((a, b) => b.count - a.count);
}
function checkColor(project: Project, id: string | null): void {
  if (id !== null && !project.palette.colors.some(c => c.id === id)) throw new Error('未知色号');
}
function checkIndex(project: Project, index: number): void {
  if (!Number.isInteger(index) || index < 0 || index >= project.cells.length) throw new Error('格子索引越界');
}
export function paint(project: Project, indices: number[], colorId: string | null): Project {
  checkColor(project, colorId);
  const cells = [...project.cells], completed = [...project.completed];
  for (const i of indices) {
    checkIndex(project, i);
    if (cells[i] !== colorId) { cells[i] = colorId; completed[i] = false; }
  }
  return { ...project, cells, completed };
}
export function floodFill(project: Project, index: number, colorId: string | null): Project {
  checkIndex(project, index); checkColor(project, colorId);
  const from = project.cells[index];
  if (from === colorId) return paint(project, [], colorId);
  const stack = [index], visited = new Uint8Array(project.cells.length), indices: number[] = [];
  while (stack.length) {
    const i = stack.pop()!;
    if (visited[i] || project.cells[i] !== from) continue;
    visited[i] = 1; indices.push(i);
    const x = i % project.width, y = Math.floor(i / project.width);
    if (x > 0) stack.push(i - 1);
    if (x + 1 < project.width) stack.push(i + 1);
    if (y > 0) stack.push(i - project.width);
    if (y + 1 < project.height) stack.push(i + project.width);
  }
  return paint(project, indices, colorId);
}
export function replaceColor(project: Project, from: string | null, to: string | null): Project {
  checkColor(project, from);
  return paint(project, project.cells.flatMap((id, i) => id === from ? [i] : []), to);
}
export function transform(project: Project, kind: 'flipH' | 'flipV' | 'rotate'): Project {
  if (!['flipH', 'flipV', 'rotate'].includes(kind)) throw new Error('未知变换');
  const width = kind === 'rotate' ? project.height : project.width;
  const height = kind === 'rotate' ? project.width : project.height;
  const cells = [...project.cells], completed = [...project.completed];
  for (let y = 0; y < project.height; y++) for (let x = 0; x < project.width; x++) {
    const nx = kind === 'flipH' ? width - 1 - x : kind === 'rotate' ? width - 1 - y : x;
    const ny = kind === 'flipV' ? height - 1 - y : kind === 'rotate' ? x : y;
    const source = y * project.width + x, target = ny * width + nx;
    cells[target] = project.cells[source]; completed[target] = project.completed[source];
  }
  return { ...project, width, height, cells, completed };
}
export function resizeProject(project: Project, width: number, height: number): Project {
  dimension(width); dimension(height);
  const cells: (string | null)[] = Array(width * height).fill(null), completed: boolean[] = Array(width * height).fill(false);
  for (let y = 0; y < Math.min(height, project.height); y++) for (let x = 0; x < Math.min(width, project.width); x++) {
    cells[y * width + x] = project.cells[y * project.width + x];
    completed[y * width + x] = project.completed[y * project.width + x];
  }
  return { ...project, width, height, cells, completed };
}
export function quantize(rgba: Uint8ClampedArray, width: number, height: number, palette: Palette, maxColors: number): Project {
  const project = createProject(width, height, palette);
  if (!(rgba instanceof Uint8ClampedArray) || rgba.length !== width * height * 4) throw new Error('像素数量不匹配');
  if (!Number.isInteger(maxColors) || maxColors < 1 || maxColors > 4096) throw new Error('色数必须为 1 至 4096 的整数');
  const colors = project.palette.colors.map(c => ({ id: c.id, rgb: [1, 3, 5].map(i => parseInt(c.hex.slice(i, i + 2), 16)) }));
  const nearest = (offset: number, candidates: typeof colors): string => {
    let best = candidates[0], distance = Infinity;
    for (const c of candidates) {
      const d = c.rgb.reduce((sum, channel, i) => sum + (channel - rgba[offset + i]) ** 2, 0);
      if (d < distance) { best = c; distance = d; }
    }
    return best.id;
  };
  const histogram = new Map<string, number>();
  for (let i = 0; i < project.cells.length; i++) if (rgba[i * 4 + 3] >= 128) {
    const id = nearest(i * 4, colors); project.cells[i] = id;
    histogram.set(id, (histogram.get(id) ?? 0) + 1);
  }
  if (histogram.size > maxColors) {
    const selected = new Set([...histogram].sort((a, b) => b[1] - a[1]).slice(0, maxColors).map(([id]) => id));
    const candidates = colors.filter(c => selected.has(c.id));
    for (let i = 0; i < project.cells.length; i++) if (project.cells[i] !== null) project.cells[i] = nearest(i * 4, candidates);
  }
  return project;
}
export function exportCsv(project: Project): string {
  const quote = (value: string | number): string => {
    const text = String(value);
    const safe = /^[=+@\-\t\r\n]/.test(text) ? `'${text}` : text;
    return `"${safe.replaceAll('"', '""')}"`;
  };
  const rows: (string | number)[][] = [['palette', 'color_id', 'name', 'hex', 'count'], ...usage(project).map(({ color, count }) => [project.palette.name, color.id, color.name, color.hex, count])];
  return '\uFEFF' + rows.map(row => row.map(quote).join(',')).join('\r\n') + '\r\n';
}
