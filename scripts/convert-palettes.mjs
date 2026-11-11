import { readdir, readFile, writeFile } from 'node:fs/promises';

const data = new URL('./data/beadcolors/', import.meta.url);
const names = { artkal_a: 'Artkal A', artkal_c: 'Artkal C', artkal_m: 'Artkal M', artkal_r: 'Artkal R', artkal_s: 'Artkal S', hama: 'Hama Midi', hama_maxi: 'Hama Maxi', hama_mini: 'Hama Mini', nabbi: 'Nabbi', perler: 'Perler Midi', perler_mini: 'Perler Mini', yant: 'Yant' };
function parseCsv(text) {
  const rows = []; let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') { field += '"'; i++; }
      else if (quoted || field.length === 0) quoted = !quoted;
      else field += c;
    } else if (!quoted && (c === ',' || c === '\n')) {
      row.push(field.replace(/\r$/, '')); field = '';
      if (c === '\n') { rows.push(row); row = []; }
    } else field += c;
  }
  if (quoted) throw new Error('Unclosed CSV quote');
  if (field || row.length) { row.push(field.replace(/\r$/, '')); rows.push(row); }
  return rows;
}
const palettes = [];
for (const filename of (await readdir(data)).filter(f => f.endsWith('.csv')).sort()) {
  const id = filename.slice(0, -4);
  const seen = new Set();
  const colors = parseCsv(await readFile(new URL(filename, data), 'utf8')).map(row => {
    const rgb = row.slice(3, 6).map(Number);
    if (row.length !== 13 || !row[0] || !row[1] || seen.has(row[0]) || rgb.some(n => !Number.isInteger(n) || n < 0 || n > 255)) throw new Error(`Invalid row in ${filename}: ${row[0]}`);
    seen.add(row[0]);
    return { id: `${id}:${row[0]}`, name: row[1], hex: '#' + rgb.map(n => n.toString(16).padStart(2, '0')).join('').toUpperCase() };
  });
  palettes.push({ id, name: names[id] ?? id, colors });
}
await writeFile(new URL('../src/palettes.ts', import.meta.url), `import type { Palette } from './core';\n\nexport const palettes: Palette[] = ${JSON.stringify(palettes, null, 2)};\n`);
console.log(`Generated ${palettes.length} palettes with ${palettes.reduce((n, p) => n + p.colors.length, 0)} colors.`);
