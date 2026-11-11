import './style.css';
import { createProject, parseProject, serializeProject, parsePalette, usage, paint, floodFill, replaceColor, transform, resizeProject, quantize, exportCsv, type Project } from './core';
import { palettes } from './palettes';
import { BeadView } from './view3d';

// Capture the untouched build document before mounting any interface.
const pristineDocument = '<!doctype html>\n' + document.documentElement.outerHTML;
const app = document.querySelector<HTMLDivElement>('#app')!;
let project = createProject(29, 29, palettes[0]);
let embedded = false;
let startupError = '';
try {
  const data = document.querySelector('#perler-project');
  if (data?.textContent) { project = parseProject(data.textContent); embedded = true; }
} catch (error) { startupError = String(error); }
let selected = project.palette.colors[0].id;
let tool = 'paint';
let zoom = 20;
let filter = '';
let past: Project[] = [], future: Project[] = [];
let stroke: Project | null = null;
let lastIndex = -1;
let markedInStroke = new Set<number>();
let view: BeadView | null = null;
let dirty = false;
let selection = new Set<number>();
let selectionStart = -1;
let polygon: [number, number][] = [];
let moving = false;
let panStart: { x: number; y: number; left: number; top: number } | null = null;
let lineAnchor = -1;
const draftKey = 'image-to-perler-draft-v1';
app.innerHTML = `
<header><div><h1>拼豆工坊</h1><span>Image to Perler · 本地离线工作台</span></div><div class="actions"><button id="open-project">打开项目</button><button id="save-project" class="primary">保存项目</button><button id="export-html">导出离线 HTML</button></div></header>
<div class="workspace">
<aside class="settings"><h2>图纸设置</h2><label>作品名称<input id="name" maxlength="200"></label><div class="pair"><label>宽度 / 格<input id="width" type="number" min="1" max="256"></label><label>高度 / 格<input id="height" type="number" min="1" max="256"></label></div><div class="actions"><button id="resize">调整尺寸</button><button id="new">新建空白</button></div><label>物理板边长<select id="board"><option>29</option><option>36</option><option>52</option><option>78</option></select></label>
<h2>图片与色板</h2><label>品牌 / 系列<select id="palette"></select></label><button id="import-palette">导入 JSON 色板</button><button id="map-palette">将现图映射至所选色板</button><p class="hint">映射会按 RGB 最近色重新配色，可撤销。</p><label>最多颜色数<input id="max-colors" type="number" min="1" max="256" value="24"></label><label class="check"><input id="smooth" type="checkbox">平滑缩放图片</label><button id="import-image" class="primary">导入图片并转换</button><p class="hint">按设置尺寸缩放，透明区域保留空格。图片仅在本机处理。</p>
<h2>项目恢复</h2><button id="restore">恢复本机草稿</button><p class="hint">草稿不会自动覆盖打开的项目。长期保存请导出项目文件。</p></aside>
<main><div class="toolbar" role="toolbar" aria-label="图纸工具"><button data-tool="paint">画笔</button><button data-tool="erase">橡皮</button><button data-tool="fill">填充</button><button data-tool="pick">吸色</button><button data-tool="replace">替换同色</button><button data-tool="done">制作标记</button><button id="undo">撤销</button><button id="redo">重做</button></div><div class="toolbar secondary"><button data-transform="flipH">水平翻转</button><button data-transform="flipV">垂直翻转</button><button data-transform="rotate">旋转 90°</button><label class="check"><input id="codes" type="checkbox">色号</label><label class="check"><input id="grid" type="checkbox" checked>网格</label><label>缩放 <input id="zoom" type="range" min="6" max="48" value="20"></label><button id="toggle-3d">3D 预览</button></div><div id="canvas-wrap"><canvas id="board-canvas" tabindex="0" aria-label="拼豆图纸；方向键移动，空格使用当前工具"></canvas></div><div id="three" hidden></div><div class="canvas-footer"><span id="position">点击图纸开始编辑</span><span id="stats"></span></div><p id="status" role="status" aria-live="polite"></p><div class="actions export-actions"><button id="export-png">导出图纸 PNG</button><button id="export-csv">导出用量 CSV</button><button id="print">打印图纸</button></div></main>
<aside class="colors"><h2>颜色与用量</h2><p id="current-palette"></p><label>搜索色号或名称<input id="search" type="search" placeholder="输入色号或名称"></label><label class="check"><input id="used-only" type="checkbox">仅显示已用颜色</label><button id="clear-filter">取消图纸颜色筛选</button><p class="hint">点击色卡选择画笔颜色；双击色卡仅突出该颜色。</p><div id="color-list"></div></aside></div>
<input id="project-file" type="file" accept=".json,application/json" hidden><input id="palette-file" type="file" accept=".json,application/json" hidden><input id="image-file" type="file" accept="image/png,image/jpeg,image/webp,image/gif,image/bmp" hidden>`;
const el = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const input = (id: string) => el<HTMLInputElement>(id);
const canvas = el<HTMLCanvasElement>('board-canvas');
const wrap = el('canvas-wrap');
const selectionBar = document.createElement('div'); selectionBar.className = 'toolbar';
selectionBar.innerHTML = `<button data-tool="rect">矩形选区</button><button data-tool="lasso">套索选区</button><button data-tool="move">移动选区</button><button data-tool="pan">平移视图</button><button id="selection-fill">填充选区</button><button id="selection-delete">删除选区</button><button id="selection-clear">取消选区</button><button id="despeckle">去孤点</button>`;
wrap.before(selectionBar);
const help = document.createElement('p'); help.className = 'hint'; help.textContent = 'Shift + 画笔点击连接上一点；中键或平移工具拖动视图。选区限制画笔操作，移动会覆盖目标格；Esc 取消选区。去孤点移除八邻域均为空的单颗豆。'; wrap.before(help);
const threeOptions = document.createElement('div'); threeOptions.className = 'toolbar'; threeOptions.id = 'three-options'; threeOptions.hidden = true;
threeOptions.innerHTML = `<label class="check"><input id="edit-3d" type="checkbox">启用 3D 网格编辑</label><label>熔豆程度 <input id="melt" type="range" min="0" max="100" value="0"></label><span class="hint">编辑时左键使用当前工具，空格可添加；Alt + 左键旋转，右键平移。</span>`;
el('three').before(threeOptions);
let moveSelection = new Set<number>();
el('selection-fill').onclick = () => { if (selection.size) commit(paint(project, [...selection], selected)); else status('请先创建选区。'); };
el('selection-delete').onclick = () => { if (selection.size) commit(paint(project, [...selection], null)); else status('请先创建选区。'); };
el('selection-clear').onclick = () => { selection.clear(); draw(); };
el('despeckle').onclick = () => {
  const isolated = project.cells.flatMap((id, i) => {
    if (!id || (selection.size && !selection.has(i))) return [];
    const x = i % project.width, y = Math.floor(i / project.width);
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if ((dx || dy) && x + dx >= 0 && x + dx < project.width && y + dy >= 0 && y + dy < project.height && project.cells[(y + dy) * project.width + x + dx]) return [];
    return [i];
  });
  commit(paint(project, isolated, null)); status(`已移除 ${isolated.length} 个孤点，可撤销。`);
};
el('map-palette').onclick = () => guard(() => {
  const palette = targetPalette();
  const rgb = (hex: string) => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
  const targets = palette.colors.map(c => ({ id: c.id, rgb: rgb(c.hex) }));
  const mapped = new Map(project.palette.colors.map(c => {
    const source = rgb(c.hex); let best = targets[0], distance = Infinity;
    for (const candidate of targets) { const d = candidate.rgb.reduce((sum, value, i) => sum + (value - source[i]) ** 2, 0); if (d < distance) { best = candidate; distance = d; } }
    return [c.id, best.id];
  }));
  install({ ...project, palette, cells: project.cells.map(id => id === null ? null : mapped.get(id)!) }); status('已按 RGB 最近色映射，空格和制作标记保留，可撤销。');
});
function status(message: string) { el('status').textContent = message; }
function guard(action: () => void) { try { action(); } catch (error) { status(error instanceof Error ? error.message : String(error)); } }
function stash() {
  dirty = true;
  try { localStorage.setItem(draftKey, serializeProject(project)); } catch { status('浏览器无法保存草稿，请下载项目文件。'); }
}
function commit(next: Project) {
  if (JSON.stringify(next) === JSON.stringify(project)) return;
  if (next.width !== project.width || next.height !== project.height) { selection.clear(); lineAnchor = -1; }
  past.push(project); if (past.length > 50) past.shift(); future = []; project = next; stash(); render();
}
function install(next: Project) { selected = next.palette.colors[0].id; filter = ''; selection.clear(); commit(next); render(); }
function dimensions() { return [Number(input('width').value), Number(input('height').value)] as const; }
function targetPalette() { return palettes.find(p => p.id === el<HTMLSelectElement>('palette').value)!; }
function paletteOptions() {
  const select = el<HTMLSelectElement>('palette'); select.replaceChildren();
  for (const p of palettes) { const option = new Option(p.name, p.id); select.add(option); }
}
paletteOptions();
function render() {
  cursor = Math.min(cursor, project.cells.length - 1);
  input('name').value = project.name; input('width').value = String(project.width); input('height').value = String(project.height);
  const boards = el<HTMLSelectElement>('board');
  if (![...boards.options].some(o => o.value === String(project.boardSize))) boards.add(new Option(String(project.boardSize)));
  boards.value = String(project.boardSize);
  el('current-palette').textContent = project.palette.name;
  const counts = usage(project), total = counts.reduce((sum, c) => sum + c.count, 0);
  el('stats').textContent = `${project.width} × ${project.height} 格 · ${total} 颗 · ${counts.length} 色 · 已完成 ${project.completed.filter(Boolean).length} 颗`;
  el<HTMLButtonElement>('undo').disabled = !past.length; el<HTMLButtonElement>('redo').disabled = !future.length;
  document.querySelectorAll<HTMLButtonElement>('[data-tool]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.tool === tool)));
  renderColors(); draw(); if (view) view.update(project);
}
function renderColors() {
  const list = el('color-list'); list.replaceChildren();
  const counts = new Map(usage(project).map(c => [c.color.id, c.count]));
  const query = input('search').value.toLowerCase();
  for (const color of project.palette.colors) {
    if (!(color.id + color.name).toLowerCase().includes(query) || (input('used-only').checked && !counts.has(color.id))) continue;
    const button = document.createElement('button'); button.className = 'color-row'; button.setAttribute('aria-pressed', String(selected === color.id));
    const swatch = document.createElement('span'); swatch.className = 'swatch'; swatch.style.backgroundColor = color.hex;
    const label = document.createElement('span'); label.textContent = `${color.id.split(':').slice(1).join(':')} · ${color.name}`;
    const count = document.createElement('strong'); count.textContent = String(counts.get(color.id) ?? 0);
    button.append(swatch, label, count); button.title = `${color.id} ${color.hex}`;
    button.onclick = () => { selected = color.id; renderColors(); };
    button.ondblclick = () => { filter = color.id; draw(); status(`正在突出色号 ${color.id}`); };
    list.append(button);
  }
}
let cursor = 0;
function draw(target = canvas, size = zoom, exportMode = false) {
  target.width = project.width * size; target.height = project.height * size;
  const ctx = target.getContext('2d')!; ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, target.width, target.height);
  const colors = new Map(project.palette.colors.map(c => [c.id, c]));
  for (let i = 0; i < project.cells.length; i++) {
    const x = i % project.width * size, y = Math.floor(i / project.width) * size, id = project.cells[i];
    ctx.globalAlpha = filter && id !== filter && !exportMode ? 0.15 : 1;
    if (id) {
      const color = colors.get(id)!; ctx.fillStyle = color.hex; ctx.fillRect(x, y, size, size);
      if (input('codes').checked && size >= 18) {
        const rgb = [1, 3, 5].map(n => parseInt(color.hex.slice(n, n + 2), 16));
        ctx.fillStyle = rgb[0] * .299 + rgb[1] * .587 + rgb[2] * .114 > 150 ? '#111' : '#fff';
        ctx.font = `${Math.max(7, size / 3)}px sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText(id.split(':').slice(1).join(':'), x + size / 2, y + size / 2, size - 2);
      }
      if (project.completed[i]) { ctx.strokeStyle = '#111'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x + size * .2, y + size * .5); ctx.lineTo(x + size * .4, y + size * .75); ctx.lineTo(x + size * .8, y + size * .2); ctx.stroke(); }
    } else { ctx.fillStyle = '#e4e4e4'; ctx.fillRect(x + size / 2 - 1, y + size / 2 - 1, 2, 2); }
  }
  ctx.globalAlpha = 1;
  if (input('grid').checked || exportMode) {
    for (let x = 0; x <= project.width; x++) { ctx.strokeStyle = x % project.boardSize === 0 ? '#454545' : '#c8c8c8'; ctx.lineWidth = x % project.boardSize === 0 ? 2 : .5; ctx.beginPath(); ctx.moveTo(x * size, 0); ctx.lineTo(x * size, target.height); ctx.stroke(); }
    for (let y = 0; y <= project.height; y++) { ctx.strokeStyle = y % project.boardSize === 0 ? '#454545' : '#c8c8c8'; ctx.lineWidth = y % project.boardSize === 0 ? 2 : .5; ctx.beginPath(); ctx.moveTo(0, y * size); ctx.lineTo(target.width, y * size); ctx.stroke(); }
  }
  if (!exportMode) {
    ctx.fillStyle = 'rgba(50,100,230,.22)'; ctx.strokeStyle = '#2459ce'; ctx.lineWidth = 1;
    for (const i of selection) { const x = i % project.width * size, y = Math.floor(i / project.width) * size; ctx.fillRect(x, y, size, size); ctx.strokeRect(x + .5, y + .5, size - 1, size - 1); }
    if (polygon.length) { ctx.beginPath(); polygon.forEach(([x, y], i) => i ? ctx.lineTo(x * size, y * size) : ctx.moveTo(x * size, y * size)); ctx.stroke(); }
  }
  if (!exportMode && document.activeElement === canvas) { ctx.strokeStyle = '#e00050'; ctx.lineWidth = 2; ctx.strokeRect(cursor % project.width * size + 1, Math.floor(cursor / project.width) * size + 1, size - 2, size - 2); }
}
function apply(index: number) {
  if (!['paint', 'erase', 'fill', 'pick', 'replace', 'done'].includes(tool) || (selection.size && !selection.has(index))) return;
  const before = project;
  if (tool === 'pick') { if (project.cells[index]) selected = project.cells[index]!; renderColors(); return; }
  if (tool === 'done' && markedInStroke.has(index)) return;
  markedInStroke.add(index);
  if (tool === 'done') { if (project.cells[index]) { const completed = [...project.completed]; completed[index] = !completed[index]; project = { ...project, completed }; } }
  else if (tool === 'fill') project = floodFill(project, index, selected);
  else if (tool === 'replace') project = replaceColor(project, project.cells[index], selected);
  else project = paint(project, [index], tool === 'erase' ? null : selected);
  if (selection.size) project = { ...project, cells: project.cells.map((id, i) => selection.has(i) ? id : before.cells[i]), completed: project.completed.map((done, i) => selection.has(i) ? done : before.completed[i]) };
  draw();
}
function point(event: PointerEvent) { const box = canvas.getBoundingClientRect(); const x = Math.floor((event.clientX - box.left) * canvas.width / box.width / zoom), y = Math.floor((event.clientY - box.top) * canvas.height / box.height / zoom); return x >= 0 && y >= 0 && x < project.width && y < project.height ? y * project.width + x : -1; }
function line(from: number, to: number) {
  const x = from % project.width, y = Math.floor(from / project.width), dx = to % project.width - x, dy = Math.floor(to / project.width) - y;
  const steps = Math.max(Math.abs(dx), Math.abs(dy));
  for (let n = 0; n <= steps; n++) apply(Math.round(y + dy * (steps ? n / steps : 0)) * project.width + Math.round(x + dx * (steps ? n / steps : 0)));
}
canvas.onpointerdown = event => {
  if (event.button !== 0 && event.button !== 1) return;
  event.preventDefault(); canvas.focus(); canvas.setPointerCapture(event.pointerId);
  if (tool === 'pan' || event.button === 1) { panStart = { x: event.clientX, y: event.clientY, left: wrap.scrollLeft, top: wrap.scrollTop }; return; }
  const index = point(event); if (index < 0) return;
  cursor = index; lastIndex = index;
  if (tool === 'rect' || tool === 'lasso') { selection.clear(); selectionStart = index; polygon = [[index % project.width + .5, Math.floor(index / project.width) + .5]]; selection.add(index); draw(); return; }
  if (tool === 'move') { if (!selection.has(index)) { status('请从选区内部拖动。'); return; } moving = true; selectionStart = index; moveSelection = new Set(selection); stroke = project; return; }
  markedInStroke.clear(); stroke = project;
  if (event.shiftKey && lineAnchor >= 0 && ['paint', 'erase'].includes(tool)) line(lineAnchor, index); else apply(index);
  lineAnchor = index;
};
canvas.onpointermove = event => {
  if (panStart) { wrap.scrollLeft = panStart.left - event.clientX + panStart.x; wrap.scrollTop = panStart.top - event.clientY + panStart.y; return; }
  const index = point(event); if (index < 0) return;
  if (selectionStart >= 0) {
    const x = index % project.width, y = Math.floor(index / project.width), sx = selectionStart % project.width, sy = Math.floor(selectionStart / project.width);
    if (moving && stroke) {
      const xs = [...moveSelection].map(i => i % project.width), ys = [...moveSelection].map(i => Math.floor(i / project.width));
      const dx = Math.max(-Math.min(...xs), Math.min(project.width - 1 - Math.max(...xs), x - sx));
      const dy = Math.max(-Math.min(...ys), Math.min(project.height - 1 - Math.max(...ys), y - sy));
      const cells = [...stroke.cells], completed = [...stroke.completed]; selection.clear();
      for (const i of moveSelection) { cells[i] = null; completed[i] = false; }
      for (const i of moveSelection) { const dest = i + dx + dy * project.width; cells[dest] = stroke.cells[i]; completed[dest] = stroke.completed[i]; selection.add(dest); }
      project = { ...stroke, cells, completed };
    } else if (tool === 'rect') {
      selection.clear(); for (let yy = Math.min(sy, y); yy <= Math.max(sy, y); yy++) for (let xx = Math.min(sx, x); xx <= Math.max(sx, x); xx++) selection.add(yy * project.width + xx);
    } else if (tool === 'lasso') { polygon.push([x + .5, y + .5]); }
    draw(); return;
  }
  el('position').textContent = `列 ${index % project.width + 1} · 行 ${Math.floor(index / project.width) + 1} · ${project.cells[index] ?? '空格'}`;
  if (stroke && index !== lastIndex && ['paint', 'erase', 'done'].includes(tool)) {
    const x0 = lastIndex % project.width, y0 = Math.floor(lastIndex / project.width), x1 = index % project.width, y1 = Math.floor(index / project.width);
    const steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
    for (let n = 1; n <= steps; n++) apply(Math.round(y0 + (y1 - y0) * n / steps) * project.width + Math.round(x0 + (x1 - x0) * n / steps));
    lastIndex = index;
  }
};
function finishStroke() {
  panStart = null;
  if (selectionStart >= 0 && tool === 'lasso' && polygon.length > 2) {
    selection.clear();
    for (let i = 0; i < project.cells.length; i++) {
      const x = i % project.width + .5, y = Math.floor(i / project.width) + .5; let inside = false;
      for (let a = 0, b = polygon.length - 1; a < polygon.length; b = a++) {
        const [ax, ay] = polygon[a], [bx, by] = polygon[b];
        if ((ay > y) !== (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) inside = !inside;
      }
      if (inside) selection.add(i);
    }
  }
  selectionStart = -1; polygon = []; moving = false;
  if (stroke) { const next = project; project = stroke; stroke = null; commit(next); }
  draw();
}
canvas.onpointerup = finishStroke; canvas.onpointercancel = finishStroke; canvas.onlostpointercapture = finishStroke;
canvas.onkeydown = event => { if (event.key === 'Escape') { selection.clear(); draw(); return; } if (event.key === 'Delete' || event.key === 'Backspace') { event.preventDefault(); el('selection-delete').click(); return; } const delta: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -project.width, ArrowDown: project.width }; if (event.key in delta) { event.preventDefault(); cursor = Math.max(0, Math.min(project.cells.length - 1, cursor + delta[event.key])); draw(); } else if (event.key === ' ') { event.preventDefault(); markedInStroke.clear(); stroke = project; apply(cursor); finishStroke(); } };
canvas.onfocus = () => draw(); canvas.onblur = () => draw();
document.querySelectorAll<HTMLButtonElement>('[data-tool]').forEach(button => button.onclick = () => { finishStroke(); tool = button.dataset.tool!; render(); });
document.querySelectorAll<HTMLButtonElement>('[data-transform]').forEach(button => button.onclick = () => { finishStroke(); selection.clear(); lineAnchor = -1; commit(transform(project, button.dataset.transform as 'flipH' | 'flipV' | 'rotate')); });
el('undo').onclick = () => { finishStroke(); lineAnchor = -1; if (past.length) { future.push(project); project = past.pop()!; selected = project.palette.colors[0].id; filter = ''; selection.clear(); stash(); render(); } };
el('redo').onclick = () => { finishStroke(); lineAnchor = -1; if (future.length) { past.push(project); project = future.pop()!; selected = project.palette.colors[0].id; filter = ''; selection.clear(); stash(); render(); } };
input('name').onchange = () => guard(() => { const next = { ...project, name: input('name').value }; serializeProject(next); commit(next); });
el('resize').onclick = () => guard(() => { const [w, h] = dimensions(); if ((w < project.width || h < project.height) && !confirm('缩小尺寸会裁掉右侧或下方格子，继续吗？')) return; commit(resizeProject(project, w, h)); });
el('new').onclick = () => guard(() => { if (!confirm('新建空白图纸？当前作品可通过撤销找回。')) return; const [w, h] = dimensions(); install(createProject(w, h, targetPalette())); });
el('board').onchange = () => commit({ ...project, boardSize: Number(el<HTMLSelectElement>('board').value) });
input('zoom').oninput = () => { zoom = Number(input('zoom').value); draw(); };
for (const id of ['codes', 'grid']) input(id).onchange = () => draw();
input('search').oninput = renderColors; input('used-only').onchange = renderColors;
el('clear-filter').onclick = () => { filter = ''; draw(); status('已显示所有颜色'); };
function download(data: Blob, filename: string) { const url = URL.createObjectURL(data); const a = document.createElement('a'); a.href = url; a.download = filename; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
function saveText(text: string, extension: string, type: string) { download(new Blob([text], { type }), `${project.name.replace(/[<>:"/\\|?*]/g, '_')}.${extension}`); }
el('save-project').onclick = () => { saveText(serializeProject(project), 'json', 'application/json'); dirty = false; status('项目文件已生成，请确认浏览器完成下载。'); };
el('export-csv').onclick = () => saveText(exportCsv(project), 'csv', 'text/csv;charset=utf-8');
el('export-png').onclick = () => { const output = document.createElement('canvas'); draw(output, Math.min(32, Math.floor(8192 / Math.max(project.width, project.height))), true); output.toBlob(blob => { if (blob) download(blob, `${project.name}.png`); }); };
el('print').onclick = () => window.print();
el('export-html').onclick = () => guard(() => {
  if (document.querySelector('script[src]')) throw new Error('开发模式不支持独立 HTML 导出，请先构建并打开 dist/index.html。');
  const parsed = new DOMParser().parseFromString(pristineDocument, 'text/html'); parsed.querySelector('#perler-project')?.remove();
  const data = parsed.createElement('script'); data.id = 'perler-project'; data.type = 'application/json'; data.textContent = serializeProject(project).replaceAll('<', '\\u003c');
  parsed.body.prepend(data); saveText('<!doctype html>\n' + parsed.documentElement.outerHTML, 'html', 'text/html;charset=utf-8'); status('已导出含当前项目的离线工作台。');
});
for (const [button, file] of [['open-project', 'project-file'], ['import-palette', 'palette-file'], ['import-image', 'image-file']]) el(button).onclick = () => input(file).click();
input('project-file').onchange = async () => { const file = input('project-file').files?.[0]; if (!file) return; try { const next = parseProject(await file.text()); if (!dirty || confirm('打开项目并替换当前图纸？')) { install(next); dirty = false; status('已打开项目'); } } catch (error) { status(String(error)); } finally { input('project-file').value = ''; } };
input('palette-file').onchange = async () => { const file = input('palette-file').files?.[0]; if (!file) return; try { const palette = parsePalette(await file.text()); const index = palettes.findIndex(p => p.id === palette.id); if (index >= 0) throw new Error('此色板标识已存在，请使用不同标识以免混淆色号。'); palettes.push(palette); paletteOptions(); el<HTMLSelectElement>('palette').value = palette.id; status(`已导入 ${palette.name}，可用于新建或图片转换。`); } catch (error) { status(String(error)); } finally { input('palette-file').value = ''; } };
input('image-file').onchange = async () => {
  const file = input('image-file').files?.[0]; if (!file) return;
  const url = URL.createObjectURL(file);
  try {
    const image = new Image(); image.src = url; await image.decode(); const [w, h] = dimensions(); createProject(w, h, targetPalette());
    const source = document.createElement('canvas'); source.width = w; source.height = h; const ctx = source.getContext('2d')!; ctx.imageSmoothingEnabled = input('smooth').checked; ctx.drawImage(image, 0, 0, w, h);
    const next = quantize(ctx.getImageData(0, 0, w, h).data, w, h, targetPalette(), Number(input('max-colors').value)); next.name = file.name.replace(/\.[^.]+$/, '').slice(0, 200) || '图片图纸';
    if (project.cells.some(Boolean) && !confirm('图片转换将替换当前图纸，继续吗？')) return;
    install(next); status('图片已转换，可用画笔修整。');
  } catch (error) { status(`图片转换失败：${String(error)}`); } finally { URL.revokeObjectURL(url); input('image-file').value = ''; }
};
el('restore').onclick = () => guard(() => { const raw = localStorage.getItem(draftKey); if (!raw) { status('本机没有可恢复草稿。'); return; } const next = parseProject(raw); if (confirm(`恢复草稿「${next.name}」并替换当前图纸？`)) { install(next); status('已恢复草稿'); } });
input('edit-3d').onchange = () => view?.setEditing(input('edit-3d').checked);
input('melt').oninput = () => view?.setMelt(Number(input('melt').value) / 100);
el('toggle-3d').onclick = () => {
  threeOptions.hidden = !!view;
  if (view) { view.dispose(); view = null; el('three').hidden = true; el('canvas-wrap').hidden = false; el('toggle-3d').textContent = '3D 预览'; return; }
  try { el('three').hidden = false; view = new BeadView(el('three'), (index, phase) => {
    if (phase === 'end') { finishStroke(); return; }
    if (phase === 'start') { stroke = project; markedInStroke.clear(); lastIndex = index; }
    if (!stroke) return;
    if (phase === 'start' || ['paint', 'erase', 'done'].includes(tool)) { if (phase === 'move') line(lastIndex, index); else apply(index); lastIndex = index; view?.update(project); }
  }); view.update(project); view.setEditing(input('edit-3d').checked); view.setMelt(Number(input('melt').value) / 100); el('canvas-wrap').hidden = true; el('toggle-3d').textContent = '返回 2D'; status('拖动旋转，滚轮缩放，右键拖动平移。'); }
  catch (error) { view?.dispose(); view = null; el('three').hidden = true; el('canvas-wrap').hidden = false; status(`无法启动 3D：${String(error)}`); }
};
window.addEventListener('beforeunload', event => { if (dirty) { event.preventDefault(); event.returnValue = ''; } });
window.addEventListener('keydown', event => { if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') { event.preventDefault(); el('save-project').click(); } if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z' && !(event.target instanceof HTMLInputElement)) { event.preventDefault(); el(event.shiftKey ? 'redo' : 'undo').click(); } });
render();
status(startupError || (embedded ? '已打开此 HTML 内嵌的项目。本机草稿仅会在主动恢复时载入。' : '导入图片或直接在空白图纸绘制。所有处理均在本机完成。'));
