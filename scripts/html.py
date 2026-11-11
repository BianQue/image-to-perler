"""Render a self-contained, dependency-free Chinese pattern editor."""

from __future__ import annotations

import json
from typing import Any


_DOCUMENT = r"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>__TITLE__</title>
<style>
:root{color-scheme:light;--ink:#202722;--muted:#6b736c;--line:#dce1dc;--paper:#fff;--bg:#f3f5f1;--accent:#28664c;--accent-soft:#e5efe8;--focus:#ad562b;font-family:Inter,"Segoe UI","Microsoft YaHei",sans-serif}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-size:14px}button,select{font:inherit}button,select{min-height:36px;border:1px solid var(--line);border-radius:6px;background:var(--paper);color:var(--ink)}button{cursor:pointer;padding:7px 11px}button:hover:not(:disabled){border-color:var(--accent);background:var(--accent-soft)}button:disabled{opacity:.4;cursor:default}button:focus-visible,select:focus-visible,canvas:focus-visible{outline:3px solid #b2cdbb;outline-offset:2px}button.primary{background:var(--accent);color:white;border-color:var(--accent)}header{padding:22px 28px 18px;background:var(--paper);border-bottom:1px solid var(--line)}.heading{display:flex;align-items:baseline;gap:14px;flex-wrap:wrap}h1{font-size:23px;margin:0;font-weight:650;letter-spacing:.02em}.source{color:var(--muted);font-size:13px}.toolbar{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:17px}.size-picker{display:flex;align-items:center;gap:8px;margin-right:6px}.toolbar .divider{height:24px;width:1px;background:var(--line);margin:0 3px}.layout{display:grid;grid-template-columns:minmax(0,1fr) 285px;gap:18px;padding:18px;max-width:1800px;margin:auto}.workspace{min-width:0}.board-shell{background:var(--paper);border:1px solid var(--line);border-radius:9px;padding:14px}.board-meta{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px}.board-meta strong{font-size:16px}.muted{color:var(--muted)}.canvas-wrap{height:calc(100vh - 280px);min-height:300px;max-height:900px;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#f7f8f6;border-radius:5px}canvas{display:block;touch-action:none;cursor:crosshair;max-width:100%;max-height:100%}.canvas-help{display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;margin:12px 1px 0;font-size:12px;color:var(--muted)}.status{color:var(--accent);min-height:20px;margin-top:8px;font-size:12px}.panel{display:flex;flex-direction:column;gap:14px}.card{background:var(--paper);border:1px solid var(--line);border-radius:9px;padding:16px}h2{font-size:14px;margin:0 0 13px;font-weight:650}.options{display:grid;grid-template-columns:1fr 1fr;gap:10px 6px}.options label{display:flex;gap:7px;align-items:center;cursor:pointer;font-size:13px}.options input{accent-color:var(--accent);width:16px;height:16px}.palette{display:grid;grid-template-columns:1fr 1fr;gap:6px;max-height:390px;overflow:auto}.swatch{display:flex;align-items:center;gap:8px;text-align:left;padding:6px;min-width:0;font-size:12px}.swatch[aria-pressed=true]{border-color:var(--accent);background:var(--accent-soft);box-shadow:inset 0 0 0 1px var(--accent)}.swatch .color{flex:0 0 23px;width:23px;height:23px;border-radius:4px;border:1px solid #0002}.swatch .label{overflow:hidden;text-overflow:ellipsis}.swatch .count{display:block;color:var(--muted);font-size:11px;margin-top:2px}.swatch[aria-pressed=true] .count{color:var(--accent)}.exports{display:grid;grid-template-columns:1fr 1fr;gap:8px}.exports button:last-child{grid-column:1/-1}.totals{display:flex;justify-content:space-between;margin-top:12px;padding-top:12px;border-top:1px solid var(--line)}.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}footer{padding:0 20px 18px;color:var(--muted);font-size:12px;line-height:1.7;max-width:1800px;margin:auto}kbd{font-family:inherit;border:1px solid var(--line);border-radius:3px;background:var(--paper);padding:1px 4px}
@media(max-width:900px){.layout{grid-template-columns:1fr;padding:12px}.panel{display:grid;grid-template-columns:1fr 1fr}.palette{max-height:240px}.canvas-wrap{height:62vh;min-height:280px}.toolbar{gap:6px}header{padding:18px}.toolbar .divider{display:none}}
@media(max-width:540px){.panel{display:flex}.options{grid-template-columns:1fr 1fr}.canvas-wrap{height:58vh}.heading{display:block}.source{margin-top:6px}h1{font-size:20px}}
@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important}}
</style>
</head>
<body>
<header>
<div class="heading"><h1 id="title"></h1><span class="source" id="source"></span></div>
<div class="toolbar" aria-label="图纸工具">
<label class="size-picker">画板尺寸 <select id="sizes" aria-label="切换画板尺寸"></select></label>
<button id="undo" type="button" disabled>撤销</button><button id="redo" type="button" disabled>重做</button>
<span class="divider" aria-hidden="true"></span>
<button id="erase" type="button" aria-pressed="false">橡皮擦</button><button id="reset" type="button">重置本尺寸</button>
</div>
</header>
<main class="layout">
<section class="workspace" aria-label="拼豆图纸编辑区">
<div class="board-shell">
<div class="board-meta"><strong id="board-label"></strong><span id="position" class="muted">点击格子涂色</span></div>
<div class="canvas-wrap" id="canvas-wrap"><canvas id="board" tabindex="0" aria-label="拼豆网格，点击涂色，方向键移动，空格或回车涂色"></canvas></div>
<div class="canvas-help"><span>拖动连续涂色 · 右键擦除 · 焦点在画布时可用方向键</span><span><kbd>Ctrl / Cmd + Z</kbd> 撤销 · <kbd>Ctrl / Cmd + Shift + Z</kbd> 重做</span></div>
<div id="status" class="status" role="status" aria-live="polite"></div>
</div>
</section>
<aside class="panel">
<section class="card"><h2>显示选项</h2><div class="options">
<label><input id="show-grid" type="checkbox" checked>网格线</label>
<label><input id="show-ids" type="checkbox" checked>色号</label>
<label><input id="show-guides" type="checkbox">辅助分区</label>
<label><input id="highlight" type="checkbox">高亮当前色</label>
</div><div class="totals"><span>当前用量</span><strong id="total"></strong></div></section>
<section class="card"><h2>色号与用量</h2><div id="palette" class="palette" aria-label="选择画笔颜色"></div></section>
<section class="card exports"><h2 style="grid-column:1/-1;margin-bottom:2px">导出当前图纸</h2>
<button id="export-csv" type="button">网格 CSV</button><button id="export-png" type="button">图纸 PNG</button>
<button id="export-share" type="button">分享图片</button><button id="export-html" type="button" class="primary">独立 HTML（含修改）</button>
</section>
</aside>
</main>
<footer>编辑仅保存在当前页面，不会修改原始文件。关闭或刷新前请导出独立 HTML。白色表示空格；非透明内部白色会保留为颜色。分享图片由当前画板在本地生成。</footer>
<noscript>此编辑器需要 JavaScript。静态图纸与 CSV 请查看同目录的 data 和各尺寸文件夹。</noscript>
<script id="pattern-data" type="application/json">__DATA__</script>
<script>
(() => {
'use strict';
const data = JSON.parse(document.getElementById('pattern-data').textContent);
const $ = id => document.getElementById(id);
const canvas = $('board'), ctx = canvas.getContext('2d');
const history = new Map(), undone = new Map();
let currentSize = data.default_size, selected = null, erasing = false;
let geometry = {edge:0,cell:1,pad:0}, painting = null, changedDuringStroke = false;
let cursor = {x:0,y:0}, statusTimer;
const original = size => data.boards.find(board => board.size === size);
const clone = board => ({...board,rows:board.rows.map(row=>row.slice()),usage:{...board.usage}});
function state(size=currentSize) { return original(size); }
function text(id,value) { $(id).textContent=value; }
function notify(message) {
  clearTimeout(statusTimer); text('status',message);
  statusTimer=setTimeout(()=>text('status',''),4500);
}
function colors(board=state()) { return new Map(board.palette.map(color=>[color.id,color])); }
function updateCounts(board=state()) {
  board.usage={}; board.bead_count=0;
  board.rows.forEach(row=>row.forEach(id=>{if(id!==null){board.usage[id]=(board.usage[id]||0)+1;board.bead_count++;}}));
}
function init() {
  data.boards.forEach(board=>history.set(board.size,[]));
  text('title',data.title); text('source','来源：'+data.source_name); document.title=data.title;
  data.boards.forEach(board=>{
    const option=document.createElement('option'); option.value=board.size;
    option.textContent=board.size+' × '+board.size+(board.size===data.default_size?'（默认档）':'');
    $('sizes').append(option);
  });
  $('sizes').value=currentSize;
  $('sizes').addEventListener('change',()=>switchSize(Number($('sizes').value)));
  ['show-grid','show-ids','show-guides','highlight'].forEach(id=>$(id).addEventListener('change',draw));
  $('erase').addEventListener('click',()=>{erasing=!erasing;$('erase').setAttribute('aria-pressed',erasing);$('erase').textContent=erasing?'正在擦除':'橡皮擦';notify(erasing?'橡皮擦已启用，点击或拖动清除格子。':'已恢复色号画笔。');});
  $('undo').addEventListener('click',undo); $('redo').addEventListener('click',redo);
  $('reset').addEventListener('click',reset);
  $('export-csv').addEventListener('click',exportCSV); $('export-png').addEventListener('click',exportPNG);
  $('export-share').addEventListener('click',exportShare); $('export-html').addEventListener('click',exportHTML);
  new ResizeObserver(draw).observe($('canvas-wrap'));
  document.addEventListener('keydown',keyboard);
  canvas.addEventListener('contextmenu',event=>event.preventDefault());
  canvas.addEventListener('pointerdown',pointerDown);
  canvas.addEventListener('pointermove',pointerMove);
  canvas.addEventListener('pointerup',pointerUp); canvas.addEventListener('pointercancel',pointerUp);
  canvas.addEventListener('pointerleave',()=>{if(!painting)text('position','点击格子涂色');});
  selectBoard();
}
function switchSize(size) {
  currentSize=size; erasing=false; $('erase').setAttribute('aria-pressed','false'); $('erase').textContent='橡皮擦';
  cursor={x:0,y:0}; selectBoard(); notify('已切换到 '+size+' × '+size+'，各尺寸修改独立保留。');
}
function selectBoard() {
  const board=state(), palette=colors(board);
  if(!palette.has(selected))selected=board.palette.length?board.palette[0].id:null;
  renderPalette(); text('board-label',board.size+' × '+board.size+' 格');
  updateHistoryButtons(); draw();
}
function renderPalette() {
  const board=state(), container=$('palette'); container.replaceChildren();
  board.palette.forEach(color=>{
    const button=document.createElement('button'); button.type='button'; button.className='swatch';
    button.setAttribute('aria-pressed',String(color.id===selected && !erasing));
    button.setAttribute('aria-label',color.name+' '+color.hex+'，'+(board.usage[color.id]||0)+' 颗');
    const chip=document.createElement('span'); chip.className='color'; chip.style.background=color.hex;
    const label=document.createElement('span'); label.className='label'; label.textContent=color.name;
    const count=document.createElement('span'); count.className='count'; count.textContent=(board.usage[color.id]||0)+' 颗';
    label.append(count); button.append(chip,label);
    button.addEventListener('click',()=>{selected=color.id;erasing=false;$('erase').setAttribute('aria-pressed','false');$('erase').textContent='橡皮擦';renderPalette();draw();});
    container.append(button);
  });
  text('total',board.bead_count.toLocaleString('zh-CN')+' 颗');
}
function updateHistoryButtons() {
  $('undo').disabled=!(history.get(currentSize)||[]).length;
  $('redo').disabled=!(undone.get(currentSize)||[]).length;
}
function draw() {
  const board=state(), size=board.size, wrap=$('canvas-wrap'), palette=colors(board);
  const edge=Math.max(1,Math.floor(Math.min(wrap.clientWidth-4,wrap.clientHeight-4)));
  const pad=size>=78?18:15, available=Math.max(1,edge-pad*2), cell=available/size;
  const pixel=Math.min(3,window.devicePixelRatio||1);
  canvas.style.width=edge+'px'; canvas.style.height=edge+'px'; canvas.width=Math.round(edge*pixel);canvas.height=Math.round(edge*pixel);
  ctx.setTransform(pixel,0,0,pixel,0,0); ctx.fillStyle='#fff';ctx.fillRect(0,0,edge,edge);
  geometry={edge,cell,pad};
  const fontSize=Math.max(6,Math.min(14,cell*.48));
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){
    const id=board.rows[y][x], px=pad+x*cell,py=pad+y*cell;
    ctx.fillStyle=id===null?'#fff':palette.get(id).hex;
    if($('highlight').checked && id!==selected)ctx.fillStyle=id===null?'#f7f8f7':'#e8ebe8';
    ctx.fillRect(px,py,cell+.15,cell+.15);
    if($('show-ids').checked && cell>=13 && id!==null){
      ctx.fillStyle=contrast(palette.get(id).hex);ctx.font='500 '+fontSize+'px "Segoe UI",sans-serif';
      ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(String(id),px+cell/2,py+cell/2+.3);
    }
  }
  if($('show-grid').checked){
    ctx.strokeStyle='#cad1ca';ctx.lineWidth=1;ctx.beginPath();
    for(let i=0;i<=size;i++){const p=Math.round(pad+i*cell)+.5;ctx.moveTo(p,pad);ctx.lineTo(p,pad+size*cell);ctx.moveTo(pad,p);ctx.lineTo(pad+size*cell,p);}
    ctx.stroke();
  }
  if($('show-guides').checked){
    ctx.strokeStyle='#8b5845';ctx.lineWidth=1.5;ctx.beginPath();
    for(let i=0;i<=size;i+=10){const p=pad+i*cell;ctx.moveTo(p,pad);ctx.lineTo(p,pad+size*cell);ctx.moveTo(pad,p);ctx.lineTo(pad+size*cell,p);}
    ctx.stroke();
    ctx.fillStyle='#76574a';ctx.font='10px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';
    for(let i=0;i<size;i+=10){const p=pad+(i+Math.min(10,size-i)/2)*cell;ctx.fillText(String(i+1),p,7);ctx.fillText(String(i+1),7,p);}
  }
  if(document.activeElement===canvas){ctx.strokeStyle='#ad562b';ctx.lineWidth=2;ctx.strokeRect(pad+cursor.x*cell+1,pad+cursor.y*cell+1,cell-2,cell-2);}
}
function contrast(hex) {
  const rgb=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16));
  return (rgb[0]*299+rgb[1]*587+rgb[2]*114)/1000>155?'#202722':'#fff';
}
function cellAt(event) {
  const rect=canvas.getBoundingClientRect(), x=event.clientX-rect.left,y=event.clientY-rect.top;
  const gx=Math.floor((x-geometry.pad)/geometry.cell),gy=Math.floor((y-geometry.pad)/geometry.cell),n=state().size;
  return gx>=0&&gy>=0&&gx<n&&gy<n?{x:gx,y:gy}:null;
}
function pointerDown(event) {
  if(event.button!==0&&event.button!==2)return;
  const point=cellAt(event); if(!point)return;
  event.preventDefault();canvas.focus();canvas.setPointerCapture(event.pointerId);
  painting={id:event.pointerId,value:event.button===2||erasing?null:selected,last:point};changedDuringStroke=false;
  pushCurrent(); paintLine(point,point);
}
function pointerMove(event) {
  const point=cellAt(event);
  if(point){cursor={...point};text('position','第 '+(point.y+1)+' 行 · 第 '+(point.x+1)+' 列');}
  if(painting&&painting.id===event.pointerId&&point){paintLine(painting.last,point);painting.last=point;}
  else draw();
}
function paintLine(from,to) {
  let x=from.x,y=from.y;const dx=Math.abs(to.x-x),sx=x<to.x?1:-1,dy=-Math.abs(to.y-y),sy=y<to.y?1:-1;
  let error=dx+dy,changed=false;
  while(true){if(paintCell(x,y,painting.value))changed=true;if(x===to.x&&y===to.y)break;const twice=2*error;if(twice>=dy){error+=dy;x+=sx;}if(twice<=dx){error+=dx;y+=sy;}}
  if(changed){changedDuringStroke=true;const board=state();updateCounts(board);renderPalette();updateHistoryButtons();draw();}
}
function paintCell(x,y,value) {
  const board=state();if(board.rows[y][x]===value)return false;
  board.rows[y][x]=value;return true;
}
function pointerUp(event) {
  if(!painting||painting.id!==event.pointerId)return;
  if(changedDuringStroke)notify('图纸已修改，可撤销；原始文件未改变。');
  else discardCurrent();
  painting=null;changedDuringStroke=false;
}
function pushCurrent(clearRedo=true) {
  if(!history.has(currentSize))history.set(currentSize,[]);
  history.get(currentSize).push(clone(state()));
  if(history.get(currentSize).length>100)history.get(currentSize).shift();
  if(clearRedo)undone.set(currentSize,[]);
}
function discardCurrent() {
  const stack=history.get(currentSize)||[];stack.pop();updateHistoryButtons();
}
function undo() {
  const stack=history.get(currentSize)||[];if(!stack.length)return;
  if(!undone.has(currentSize))undone.set(currentSize,[]);
  undone.get(currentSize).push(clone(state()));
  data.boards[data.boards.findIndex(board=>board.size===currentSize)]=stack.pop();
  selectBoard();notify('已撤销一步。');
}
function redo() {
  const stack=undone.get(currentSize)||[];if(!stack.length)return;
  pushCurrent(false);
  data.boards[data.boards.findIndex(board=>board.size===currentSize)]=stack.pop();
  selectBoard();notify('已重做一步。');
}
function reset() {
  if(!window.confirm('将本尺寸恢复为初始图纸？此操作可通过“撤销”恢复。'))return;
  pushCurrent();
  data.boards[data.boards.findIndex(board=>board.size===currentSize)]=clone(history.get(currentSize)[0]);
  selectBoard();notify('本尺寸已恢复为打开页面时的状态，可撤销。');
}
function keyboard(event) {
  const modifier=event.ctrlKey||event.metaKey;
  if(modifier&&event.key.toLowerCase()==='z'){
    event.preventDefault();event.shiftKey?redo():undo();return;
  }
  if(modifier&&event.key.toLowerCase()==='y'){event.preventDefault();redo();return;}
  if(document.activeElement!==canvas)return;
  const n=state().size;
  if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.key)){
    event.preventDefault();cursor.x=Math.max(0,Math.min(n-1,cursor.x+(event.key==='ArrowRight'?1:event.key==='ArrowLeft'?-1:0)));
    cursor.y=Math.max(0,Math.min(n-1,cursor.y+(event.key==='ArrowDown'?1:event.key==='ArrowUp'?-1:0)));draw();
  } else if(event.key===' '||event.key==='Enter'||event.key==='Delete'||event.key==='Backspace'){
    event.preventDefault();const value=event.key==='Delete'||event.key==='Backspace'?null:selected;
    pushCurrent();
    if(paintCell(cursor.x,cursor.y,value)){const board=state();updateCounts(board);renderPalette();updateHistoryButtons();draw();}
    else discardCurrent();
  }
}
function download(blob,name) {
  const url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download=name;
  document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1500);
}
function exportCSV() {
  const board=state(),lines=board.rows.map(row=>row.map(id=>id===null?'':id).join(','));
  download(new Blob(['﻿'+lines.join('\r\n')+'\r\n'],{type:'text/csv;charset=utf-8'}),'perler-'+board.size+'-grid.csv');notify('已导出当前网格 CSV。');
}
function raster(cell,share=false) {
  const board=state(),palette=colors(board),pad=share?72:32,footer=share?72:0,header=share?120:32;
  const output=document.createElement('canvas');output.width=board.size*cell+pad*2;output.height=board.size*cell+pad*2+header+footer;
  const pen=output.getContext('2d');pen.fillStyle='#f5f6f2';pen.fillRect(0,0,output.width,output.height);
  pen.fillStyle='#202722';pen.textAlign='left';pen.textBaseline='alphabetic';
  pen.font='600 26px "Microsoft YaHei",sans-serif';pen.fillText(data.title,pad,pad+22);
  pen.font='16px "Microsoft YaHei",sans-serif';pen.fillStyle='#59665c';
  pen.fillText(board.size+' × '+board.size+' 格 · '+board.bead_count+' 颗 · '+board.palette.length+' 色',pad,pad+52);
  const left=pad,top=pad+header;
  for(let y=0;y<board.size;y++)for(let x=0;x<board.size;x++){
    const id=board.rows[y][x];pen.fillStyle=id===null?'#fff':palette.get(id).hex;
    pen.fillRect(left+x*cell,top+y*cell,cell,cell);
    if(cell>=18&&id!==null){pen.fillStyle=contrast(palette.get(id).hex);pen.font='12px sans-serif';pen.textAlign='center';pen.textBaseline='middle';pen.fillText(id,left+(x+.5)*cell,top+(y+.5)*cell);}
  }
  pen.strokeStyle='#c2cac1';pen.lineWidth=1;pen.beginPath();
  for(let i=0;i<=board.size;i++){pen.moveTo(left+i*cell+.5,top);pen.lineTo(left+i*cell+.5,top+board.size*cell);pen.moveTo(left,top+i*cell+.5);pen.lineTo(left+board.size*cell,top+i*cell+.5);}
  pen.stroke();
  if(share){
    pen.textAlign='left';pen.textBaseline='alphabetic';pen.font='15px "Microsoft YaHei",sans-serif';pen.fillStyle='#445047';
    let summary=board.palette.map(color=>color.name+' '+(board.usage[color.id]||0)).join(' · ');
    if(summary.length>90)summary=summary.slice(0,89)+'…';
    pen.fillText('色号 / 用量：'+summary,pad,top+board.size*cell+38);
    pen.fillStyle='#7a827b';pen.font='13px sans-serif';pen.fillText('由本地拼豆图纸生成 · 非品牌官方色卡',pad,top+board.size*cell+63);
  }
  return output;
}
function exportPNG() {raster(Math.max(12,Math.min(28,Math.floor(1400/currentSize)))).toBlob(blob=>{download(blob,'perler-'+currentSize+'.png');notify('已导出当前 PNG 图纸。');},'image/png');}
function exportShare() {raster(Math.max(8,Math.min(18,Math.floor(1000/currentSize))),true).toBlob(blob=>{download(blob,'perler-'+currentSize+'-share.png');notify('已根据当前图纸生成分享图片。');},'image/png');}
function exportHTML() {
  const snapshot={...data,boards:data.boards.map(board=>clone(state(board.size)))};
  const node=document.getElementById('pattern-data').cloneNode(false);node.textContent=JSON.stringify(snapshot).replace(/</g,'\\u003c');
  const holder=document.createElement('div');holder.append(node);
  const originalHTML=document.documentElement.outerHTML;
  const scriptEnd='</scr'+'ipt>';
  const start=originalHTML.indexOf('<script id="pattern-data"'),end=originalHTML.indexOf(scriptEnd,start)+scriptEnd.length;
  const html='<!doctype html>\n'+originalHTML.slice(0,start)+holder.innerHTML+originalHTML.slice(end);
  download(new Blob([html],{type:'text/html;charset=utf-8'}),'perler-edited.html');notify('已导出包含全部尺寸当前修改的独立 HTML。');
}
init();
})();
</script>
</body>
</html>
"""


def render_html(result: dict[str, Any]) -> str:
    """Embed JSON safely; an exported HTML can use the same function offline."""
    title = str(result["title"])
    title = (
        title.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )
    payload = json.dumps(result, ensure_ascii=False, separators=(",", ":")).replace(
        "<", "\\u003c"
    )
    return _DOCUMENT.replace("__TITLE__", title).replace("__DATA__", payload)
