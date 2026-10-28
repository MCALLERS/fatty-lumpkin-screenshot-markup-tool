const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

function drawing(storage=new Map()) {
  const elements = new Map();
  const context = new Proxy({}, {get:(_,key)=>key==='getImageData'?()=>({}):()=>{}});
  function element() { return {listeners:{},style:{},classList:{add(){},remove(){}},value:'5',checked:false,hidden:true,width:1200,height:800,
    clientWidth:800,clientHeight:600,scrollLeft:0,scrollTop:0,
    addEventListener(name,fn){this.listeners[name]=fn;},getContext:()=>context,
    getBoundingClientRect:()=>({left:0,top:0,width:1200,height:800}),setPointerCapture(){},scrollTo(){},
    replaceChildren(){},append(){},removeAttribute(name){delete this[name];},toBlob(callback){callback({});}}; }
  const sandbox = {document:{body:element(),querySelector(s){if(!elements.has(s))elements.set(s,element());return elements.get(s);},
    querySelectorAll:()=>[],addEventListener(){},createElement:element},window:{addEventListener(){}},
    localStorage:{setItem(k,v){storage.set(k,v);},getItem(k){return storage.get(k)||null;}},requestAnimationFrame:()=>1,cancelAnimationFrame(){},
    Image:class {naturalWidth=1200;naturalHeight=800;async decode(){}},crypto:require('node:crypto').webcrypto,
    setTimeout,clearTimeout,Date,performance,AbortController};
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../Companion/app.js'),'utf8').replace(/start\(\);\s*$/, ''),sandbox);
  const run = code=>vm.runInContext(code,sandbox);
  run("state.image={};state.capture={id:'sample',width:1200,height:800};state.fit=.5;$('#complete');");
  const ink = elements.get('#ink');
  function fire(type,id,pointerType,x=20,y=20) {ink.listeners[type]({pointerId:id,pointerType,clientX:x,clientY:y,pressure:.5,button:0,preventDefault(){}});}
  return {run,fire,ink,elements,sandbox,storage};
}

test('Pencil starts drawing even when two palm contacts preceded it',()=>{
  const d=drawing();d.fire('pointerdown',1,'touch',0,0);d.fire('pointerdown',2,'touch',100,0);
  d.fire('pointerdown',3,'pen',30,30);d.fire('pointermove',3,'pen',70,70);d.fire('pointerup',3,'pen',90,90);
  assert.ok(d.run('state.strokes[0].points.length')>=2);assert.equal(d.run('state.zoom'),1);
});
test('an interrupted Pencil stroke keeps ink already drawn',()=>{
  const d=drawing();d.fire('pointerdown',1,'pen');d.fire('pointermove',1,'pen',80,80);d.fire('pointercancel',1,'pen');
  assert.equal(d.run('state.strokes.length'),1);assert.equal(d.run('state.dirty'),true);
});
test('capture failure does not prevent the first Pencil mark',()=>{
  const d=drawing();d.ink.setPointerCapture=()=>{throw Error('capture unavailable');};
  d.fire('pointerdown',1,'pen');d.fire('pointerup',1,'pen');assert.equal(d.run('state.strokes.length'),1);
});
test('a palm touching during a Pencil stroke cannot steal it',()=>{
  const d=drawing();d.fire('pointerdown',1,'pen');d.fire('pointerdown',2,'touch');d.fire('pointermove',1,'pen',80,80);d.fire('pointerup',1,'pen');
  assert.equal(d.run('state.strokes.length'),1);assert.ok(d.run('state.strokes[0].points.length')>=2);
});
test('losing capture finishes the stroke and allows the next one',()=>{
  const d=drawing();d.fire('pointerdown',1,'pen');d.fire('pointermove',1,'pen',80,80);d.fire('lostpointercapture',1,'pen');
  d.fire('pointerdown',2,'pen');d.fire('pointerup',2,'pen');assert.equal(d.run('state.strokes.length'),2);
});

test('completion appears only after the Mac acknowledges this saved image',async()=>{
  const d=drawing();let acknowledged='previous-save';
  d.sandbox.fetch=async path=>({ok:true,json:async()=>path==='/api/library'?{captures:[{id:'sample'}]}:{lastCopied:acknowledged}});
  d.run("state.captures=[{id:'sample'}];state.lastCopied='new-save';");
  await d.run('refresh()');assert.equal(d.elements.get('#complete').hidden,true);
  acknowledged='new-save';await d.run('refresh()');assert.equal(d.elements.get('#complete').hidden,false);
});
test('clipboard acknowledgement does not interrupt a new unfinished drawing',async()=>{
  const d=drawing();d.sandbox.fetch=async path=>({ok:true,json:async()=>path==='/api/library'?{captures:[{id:'sample'}]}:{lastCopied:'new-save'}});
  d.run("state.captures=[{id:'sample'}];state.lastCopied='new-save';state.dirty=true;");
  await d.run('refresh()');assert.equal(d.elements.get('#complete').hidden,true);
});

const batch="state.captures=[{id:'third',modified:3,width:1200,height:800},{id:'first',modified:1,width:1200,height:800},{id:'second',modified:2,width:1200,height:800},{id:'old',modified:0,saved:true}];syncQueue();";
test('three captures run oldest first and completed work is excluded',async()=>{
  const d=drawing();d.run(batch);assert.equal(d.run('state.queue.join()'),'first,second,third');
  await d.run("load(waiting()[0])");assert.equal(d.elements.get('#queue-position').textContent,'1 of 3');assert.equal(d.elements.get('#done').textContent,'Done & Next →');
  await d.run("saved({id:'save-one'})");assert.equal(d.run('state.capture.id'),'second');assert.equal(d.elements.get('#queue-position').textContent,'2 of 3');
  await d.run("saved({id:'save-two'})");assert.equal(d.run('state.capture.id'),'third');assert.equal(d.elements.get('#done').textContent,'Done ↗');
  await d.run("saved({id:'save-three'})");assert.equal(d.run('waiting().length'),0);assert.equal(d.run('state.lastCopied'),'save-three');
});
test('new screenshots append without replacing an unfinished drawing',async()=>{
  const d=drawing();d.run(batch);await d.run('load(waiting()[0])');d.fire('pointerdown',1,'pen');d.fire('pointerup',1,'pen');
  d.sandbox.fetch=async()=>({ok:true,json:async()=>[{id:'fourth',modified:4,width:1200,height:800},...JSON.parse(d.run('JSON.stringify(state.captures)'))].reduce((r,c)=>(r.captures.push(c),r),{captures:[]})});
  await d.run('refresh()');assert.equal(d.run('state.capture.id'),'first');assert.equal(d.run('state.strokes.length'),1);assert.equal(d.run('state.queue.join()'),'first,second,third,fourth');
});
test('refresh restores the current queue position and unfinished strokes',async()=>{
  const d=drawing();d.run(batch);await d.run('load(waiting()[0])');await d.run("saved({id:'one'})");d.fire('pointerdown',1,'pen');d.fire('pointerup',1,'pen');
  const captures=JSON.parse(d.run('JSON.stringify(state.captures)'));const resumed=drawing(d.storage);resumed.run('state.capture=null;');
  resumed.sandbox.fetch=async()=>({ok:true,json:async()=>({captures})});await resumed.run('refresh()');
  assert.equal(resumed.run('state.capture.id'),'second');assert.equal(resumed.run('state.strokes.length'),1);assert.equal(resumed.elements.get('#queue-position').textContent,'2 of 3');
});
test('a failed upload keeps the drawing and does not advance the queue',async()=>{
  const d=drawing();d.run(batch);await d.run('load(waiting()[0])');d.fire('pointerdown',1,'pen');d.fire('pointerup',1,'pen');
  d.sandbox.fetch=async()=>{throw Error('Upload interrupted');};await d.run('done()');
  assert.equal(d.run('state.capture.id'),'first');assert.equal(d.run('waiting().length'),3);assert.equal(d.run('state.dirty'),true);assert.equal(d.run('state.saving'),false);
});
test('a new batch starts at one after the previous batch is finished',async()=>{
  const d=drawing();d.run(batch);await d.run('load(waiting()[0])');for(let i=0;i<3;i++)await d.run("saved({id:'save'})");
  d.run("state.captures.push({id:'fourth',modified:4});syncQueue();");assert.equal(d.run('state.queue.join()'),'fourth');
});
test('finishing a queue clears the image but preserves saved drafts and library entries',async()=>{
  const d=drawing();d.run(batch);await d.run('load(waiting()[0])');
  for(let i=0;i<3;i++){d.fire('pointerdown',1,'pen');d.fire('pointerup',1,'pen');await d.run("saved({id:'saved'})");}
  assert.equal(d.run('state.capture'),null);assert.equal(d.run('state.image'),null);assert.equal(d.run('state.strokes.length'),0);
  assert.equal(d.elements.get('#paper').hidden,true);assert.equal(d.elements.get('#empty').hidden,false);
  assert.equal(d.run('state.captures.length'),4);assert.equal(JSON.parse(d.storage.get('screenshot-draft-third')).strokes.length,1);
  assert.equal(d.run('state.finishedCount'),3);
  const resumed=drawing(d.storage);resumed.run('state.capture=null;state.image=null;');
  const captures=JSON.parse(d.run('JSON.stringify(state.captures)'));
  resumed.sandbox.fetch=async()=>({ok:true,json:async()=>({captures})});await resumed.run('refresh()');
  assert.equal(resumed.run('state.capture'),null);
  captures.unshift({id:'new',modified:5,width:1200,height:800});await resumed.run('refresh()');assert.equal(resumed.run('state.capture.id'),'new');
});

test('a session reset clears a clean old screenshot and starts the next batch at one',async()=>{
  const d=drawing();d.run(batch);await d.run('load(waiting()[0])');
  let captures=JSON.parse(d.run('JSON.stringify(state.captures)')),session='old-session';
  d.sandbox.fetch=async()=>({ok:true,json:async()=>({captures,session:{id:session}})});
  await d.run('refresh()');
  session='new-session';captures=[];await d.run('refresh()');
  assert.equal(d.run('state.capture'),null);assert.equal(d.run('state.queue.length'),0);
  assert.equal(d.elements.get('#paper').hidden,true);assert.equal(d.elements.get('#complete').hidden,true);
  captures=[{id:'new',modified:5,width:1200,height:800}];await d.run('refresh()');
  assert.equal(d.run('state.capture.id'),'new');assert.equal(d.elements.get('#queue-position').textContent,'1 of 1');
});
test('an external session reset preserves unfinished Pencil ink for saving',async()=>{
  const d=drawing();d.run(batch);await d.run('load(waiting()[0])');
  let captures=JSON.parse(d.run('JSON.stringify(state.captures)')),session='old-session';
  d.sandbox.fetch=async()=>({ok:true,json:async()=>({captures,session:{id:session}})});
  await d.run('refresh()');d.fire('pointerdown',1,'pen');d.fire('pointerup',1,'pen');
  session='new-session';captures=[];await d.run('refresh()');
  assert.equal(d.run('state.capture.id'),'first');assert.equal(d.run('state.strokes.length'),1);assert.equal(d.run('state.dirty'),true);
  assert.match(d.elements.get('#status').textContent,/new session/i);
  assert.equal(JSON.parse(d.storage.get('screenshot-draft-first')).strokes.length,1);
  await d.run("saved({id:'historical-save'})");assert.equal(d.run('state.capture'),null);
});
