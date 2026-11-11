import assert from 'node:assert/strict';
import { stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import { createProject, paint, replaceColor, floodFill, transform, resizeProject, validateProject } from '../../src/core.ts';
const palette={id:'old',name:'Old',colors:[{id:'old:a',name:'A',hex:'#111111'},{id:'old:b',name:'B',hex:'#222222'}]};
const target={id:'new',name:'New',colors:[{id:'new:x',name:'X',hex:'#191919'}]};
const A='old:a', B='old:b', X='new:x';
const base={...createProject(3,2,palette),cells:[A,A,A,A,null,B],completed:[true,false,false,false,false,false]};
let count=0;
function test(name,fn){fn(); console.log(`PASS ${++count}: ${name}`);}
const pairs=p=>p.cells.map((c,i)=>[c,p.completed[i]]);
const same=(a,b)=>assert.deepEqual(pairs(a),pairs(b));
test('paint resets completed only on actual color change',()=>{assert.equal(paint(base,[0],B).completed[0],false);same(paint(base,[0],A),base);});
test('replaceColor resolves a concrete footprint and clears completed',()=>{const p=replaceColor(base,A,B);assert.deepEqual(p.cells,[B,B,B,B,null,B]);assert.equal(p.completed[0],false);});
for(const kind of ['rotate','flipH','flipV']) test(`${kind}: every 3x2 source coordinate maps with both fields`,()=>{
 const p=transform(base,kind); const w=kind==='rotate'?2:3,h=kind==='rotate'?3:2;
 assert.equal(p.width,w);assert.equal(p.height,h);
 for(let y=0;y<2;y++)for(let x=0;x<3;x++){
  const nx=kind==='flipH'?w-1-x:kind==='rotate'?w-1-y:x;
  const ny=kind==='flipV'?h-1-y:kind==='rotate'?x:y;
  assert.deepEqual(pairs(p)[ny*w+nx],pairs(base)[y*3+x]);
 }
});
test('four rotations and two flips round trip without information loss',()=>{
 let p=base;for(let i=0;i<4;i++)p=transform(p,'rotate');same(p,base);assert.equal(p.width,3);
 for(const k of ['flipH','flipV'])same(transform(transform(base,k),k),base);
});
test('resize shrink retains upper-left cells and drops right/bottom (not arbitrary crop UI)',()=>{const p=resizeProject(base,2,2);assert.deepEqual(pairs(p),[pairs(base)[0],pairs(base)[1],pairs(base)[3],pairs(base)[4]]);});
const main=readFileSync(new URL('../../src/main.ts',import.meta.url),'utf8');
const marker="el('map-palette').onclick = () => guard(() => {";
const body=main.split(marker)[1].split('\n});')[0];
assert.ok(body.includes('project.cells.map')&&body.includes('mapped.get'));
const actualPaletteHandler=new Function('project','targetPalette','install','status',stripTypeScriptTypes(body,{mode:'strip'}));
function mapPalette(p){let result;actualPaletteHandler(p,()=>target,v=>{result=v},()=>{});return result;}
test('actual main.ts palette handler merges A/B to X and preserves completed/null',()=>{
 const p=mapPalette(base);assert.deepEqual(p.cells,[X,X,X,X,null,X]);assert.deepEqual(p.completed,base.completed);validateProject(p);
});
test('many-to-one palette has no unique color inverse',()=>{assert.equal(mapPalette({...base,cells:base.cells.map(()=>A)}).cells[0],mapPalette({...base,cells:base.cells.map(()=>B)}).cells[0]);});
test('restoring color alone can be format-valid but semantically wrong',()=>{const changed=paint(base,[0],B);const bad={...changed,cells:[A,...changed.cells.slice(1)]};validateProject(bad);assert.notDeepEqual(pairs(bad)[0],pairs(base)[0]);});
test('raw replace replay differs from committed-effect preservation without write overlap',()=>{
 const agent=paint(base,[0],B),human=replaceColor(agent,A,null),compensated={...human,cells:[A,...human.cells.slice(1)],completed:[true,...human.completed.slice(1)]};
 const raw=replaceColor(base,A,null);assert.notDeepEqual(pairs(compensated),pairs(raw));
 console.log('  witness: saved effect keeps restored cell A/done=true; raw Replace(A,null) erases it');
});
test('raw fill replay can change a region even without overlapping committed writes',()=>{
 const start={...createProject(3,1,palette),cells:[A,A,A]},agent=paint(start,[1],B),human=floodFill(agent,0,null);
 const compensated={...human,cells:[null,A,A]};const raw=floodFill(start,0,null);assert.notDeepEqual(pairs(compensated),pairs(raw));
});
test('palette transform is not automatically equivariant with paint because paint may become a no-op',()=>{
 const a=mapPalette(paint(base,[0],B)),mapped=mapPalette(base),b=paint(mapped,[0],X);assert.equal(a.completed[0],false);assert.equal(b.completed[0],true);
});
console.log(`Source checks: ${count} passed. These check existing pure operations, not a selective-undo implementation.`);
