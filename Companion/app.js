'use strict';
const $ = s => document.querySelector(s);
const canvas = $('#ink'), ctx = canvas.getContext('2d'), paper = $('#paper'), workspace = $('#workspace');
const state = {capture:null, captures:[], queue:[], manual:false, image:null, strokes:[], redo:[], active:null, dirty:false, saving:false, tool:'pen', color:'#ed4359', zoom:1, fit:1, pending:null, submission:null, lastCopied:null, finishedCount:0};
try{const queue=JSON.parse(localStorage.getItem('screenshot-queue'));if(Array.isArray(queue))state.queue=queue.filter(x=>typeof x==='string');}catch{}
const pointers = new Map();
let frame = 0, pan = null, pinch = null, loadSerial = 0, pollBusy = false, penUntil = 0, libraryRevision = 0;
function status(text, kind='') { $('#status').textContent=text; $('#status').className=kind; }
function uuid() { return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c=>{const r=crypto.getRandomValues(new Uint8Array(1))[0]&15;return (c==='x'?r:(r&3)|8).toString(16);}); }
async function api(path, options={}) {
  const controller=new AbortController(), timeout=setTimeout(()=>controller.abort(),path==='/api/save'?30000:10000);
  try {
    const response = await fetch(path, {...options, signal:controller.signal, credentials:'same-origin', cache:'no-store'});
    let body; try { body=await response.json(); } catch(error) { if(controller.signal.aborted)throw error;throw Error('The Mac did not return a valid response. Try again.'); }
    if (!response.ok) { if(response.status===401) $('#pairing').hidden=false; throw Error(body.error || 'Connection failed. Your drawing is still here.'); }
    return body;
  } catch(error) {if(controller.signal.aborted)throw Error('The Mac took too long to respond. Your drawing is kept here. Tap Done to retry.');throw error;}
  finally{clearTimeout(timeout);}
}
function persist() {
  if(!state.capture) return;
  try { localStorage.setItem('screenshot-draft-'+state.capture.id,JSON.stringify({strokes:state.strokes,dirty:state.dirty})); }
  catch { status('Drawing is in memory. Keep this page open until you tap Done.','error'); }
}
function changed() { state.dirty=true; state.submission=null; updateButtons(); persist(); status('Drawing saved on this iPad. Tap Done when you’re ready.'); }
function waiting() {return state.queue.map(id=>state.captures.find(c=>c.id===id)).filter(c=>c&&!c.saved);}
function syncQueue() {
  state.queue=state.queue.filter(id=>state.captures.some(c=>c.id===id));
  const newcomers=state.captures.filter(c=>!c.saved&&!state.queue.includes(c.id)).sort((a,b)=>a.modified-b.modified||a.id.localeCompare(b.id));
  // A completed batch stays visible until the next batch arrives.
  if(newcomers.length&&!waiting().length)state.queue=[];
  for(const capture of newcomers)state.queue.push(capture.id);
  try{localStorage.setItem('screenshot-queue',JSON.stringify(state.queue));}catch{}
  updateButtons();
}
function updateButtons() {
  const next=waiting().find(c=>c.id!==state.capture?.id), index=state.queue.indexOf(state.capture?.id);
  $('#done').disabled=!state.capture||state.saving||!state.image;
  if(!state.saving)$('#done').textContent=next?'Done & Next →':'Done ↗';
  $('#queue-position').textContent=index>=0?(index+1)+' of '+state.queue.length:state.capture?'Saved image':'No pending screenshots';
  $('#undo').disabled=!state.strokes.length||state.saving;$('#redo').disabled=!state.redo.length||state.saving;
}
function paintStroke(context,s) {
  if(!s.points.length) return;
  context.save(); context.lineCap='round'; context.lineJoin='round'; context.strokeStyle=s.color; context.fillStyle=s.color;
  context.globalCompositeOperation=s.tool==='erase'?'destination-out':'source-over'; context.globalAlpha=s.tool==='highlight'?.28:1;
  const points=s.points;
  if(s.tool==='highlight') {
    context.lineWidth=s.width; context.beginPath();context.moveTo(points[0].x,points[0].y);for(const p of points.slice(1)) context.lineTo(p.x,p.y);context.stroke();
  } else if(points.length===1) {
    context.beginPath();context.arc(points[0].x,points[0].y,s.width*(.4+points[0].p*.6)/2,0,Math.PI*2);context.fill();
  } else {
    for(let i=1;i<points.length;i++) { const a=points[i-1],b=points[i];context.lineWidth=s.width*(s.tool==='erase'?1:.4+(a.p+b.p)*.3);context.beginPath();context.moveTo(a.x,a.y);context.lineTo(b.x,b.y);context.stroke(); }
  }
  context.restore();
}
function render() { frame=0;ctx.clearRect(0,0,canvas.width,canvas.height);for(const s of state.strokes) paintStroke(ctx,s);if(state.active)paintStroke(ctx,state.active); }
function redraw() { if(!frame) frame=requestAnimationFrame(render); }
function setZoom(value) {
  if(!state.capture) return;
  state.zoom=Math.max(state.fit*.5,Math.min(4,value));
  paper.style.width=(state.capture.width*state.zoom)+'px';paper.style.height=(state.capture.height*state.zoom)+'px';
  $('#fit').textContent=Math.round(state.zoom*100)+'% · Fit';
}
function fit() {
  if(!state.capture)return;
  state.fit=Math.min(1,(workspace.clientWidth-56)/state.capture.width,(workspace.clientHeight-56)/state.capture.height);
  state.fit=Math.max(.03,state.fit);setZoom(state.fit);workspace.scrollTo(0,0);
}
function point(event) {const r=canvas.getBoundingClientRect();return {x:(event.clientX-r.left)*canvas.width/r.width,y:(event.clientY-r.top)*canvas.height/r.height,p:event.pressure>0?event.pressure:.5};}
canvas.addEventListener('pointerdown',event=>{
  if(!state.image||state.saving)return;
  if(event.pointerType==='mouse'&&event.button!==0)return;
  event.preventDefault();
  if(event.pointerType==='pen') {
    // A hand can land before the Pencil. Give the Pencil priority over any
    // pending finger gesture, including a pinch that began before this event.
    if(state.active?.pointerType==='pen')endPointer({pointerId:state.active.id},true);
    else if(state.active) {state.active=null;redraw();}
    pointers.clear();pan=null;pinch=null;penUntil=Date.now()+500;
  } else if(state.active?.pointerType==='pen'||(event.pointerType==='touch'&&Date.now()<penUntil))return;
  // Capture is an aid, not a prerequisite for accepting ink.
  try{canvas.setPointerCapture(event.pointerId);}catch{}
  pointers.set(event.pointerId,{x:event.clientX,y:event.clientY});
  if(pointers.size===2 && event.pointerType!=='pen') {
    if(state.active?.pointerType==='touch') state.active=null;
    const [a,b]=[...pointers.values()];pinch={distance:Math.hypot(a.x-b.x,a.y-b.y),zoom:state.zoom};pan=null;redraw();return;
  }
  if(event.pointerType==='touch'&&!$('#finger').checked) {pan={id:event.pointerId,x:event.clientX,y:event.clientY,left:workspace.scrollLeft,top:workspace.scrollTop};return;}
  if(state.active)return;
  const base=Number($('#width').value);const size=state.tool==='highlight'?base*5:state.tool==='erase'?base*6:base;
  state.active={id:event.pointerId,pointerType:event.pointerType,tool:state.tool,color:state.color,width:size/state.zoom,points:[point(event)]};redraw();
});
canvas.addEventListener('pointermove',event=>{
  if(!pointers.has(event.pointerId))return;event.preventDefault();pointers.set(event.pointerId,{x:event.clientX,y:event.clientY});
  // Handle the active Pencil before consulting any touch navigation state.
  if(state.active?.id===event.pointerId&&state.active.pointerType==='pen') {
    penUntil=Date.now()+500;
    const events=event.getCoalescedEvents?.()||[event];for(const e of events.length?events:[event])state.active.points.push(point(e));redraw();return;
  }
  if(pinch&&pointers.size>=2){const[a,b]=[...pointers.values()];setZoom(pinch.zoom*Math.hypot(a.x-b.x,a.y-b.y)/pinch.distance);return;}
  if(pan?.id===event.pointerId){workspace.scrollLeft=pan.left+pan.x-event.clientX;workspace.scrollTop=pan.top+pan.y-event.clientY;return;}
  if(state.active?.id!==event.pointerId)return;
  const events=event.getCoalescedEvents?.()||[event];for(const e of events.length?events:[event]) state.active.points.push(point(e));redraw();
});
function endPointer(event,cancelled=false) {
  pointers.delete(event.pointerId);if(pan?.id===event.pointerId)pan=null;if(pointers.size<2)pinch=null;
  if(state.active?.id!==event.pointerId)return;
  const isPen=state.active.pointerType==='pen';if(isPen)penUntil=Date.now()+500;
  if(!cancelled&&Number.isFinite(event.clientX))state.active.points.push(point(event));
  // Preserve real Pencil ink when Safari interrupts the stream. Discard a
  // cancelled finger stroke, which may have been the start of a pinch.
  if(!cancelled||isPen){const {id,pointerType,...stroke}=state.active;state.strokes.push(stroke);state.redo=[];state.active=null;changed();} else state.active=null;
  redraw();
}
canvas.addEventListener('pointerup',e=>endPointer(e));canvas.addEventListener('pointercancel',e=>endPointer(e,true));
canvas.addEventListener('lostpointercapture',e=>endPointer(e,true));
canvas.addEventListener('contextmenu',e=>e.preventDefault());
// Keep Safari's native touch gestures from competing on the drawing surface.
canvas.addEventListener('touchstart',e=>e.preventDefault(),{passive:false});
canvas.addEventListener('touchmove',e=>e.preventDefault(),{passive:false});
document.querySelectorAll('[data-tool]').forEach(button=>button.addEventListener('click',()=>{state.tool=button.dataset.tool;document.querySelectorAll('[data-tool]').forEach(b=>{b.classList.toggle('chosen',b===button);b.setAttribute('aria-pressed',String(b===button));});}));
document.querySelectorAll('[data-color]').forEach(button=>button.addEventListener('click',()=>{state.color=button.dataset.color;document.querySelectorAll('[data-color]').forEach(b=>{b.classList.toggle('chosen',b===button);b.setAttribute('aria-pressed',String(b===button));});}));
$('#undo').onclick=()=>{if(state.strokes.length){state.redo.push(state.strokes.pop());changed();redraw();}};
$('#redo').onclick=()=>{if(state.redo.length){state.strokes.push(state.redo.pop());changed();redraw();}};
$('#fit').onclick=fit;$('#zoom-in').onclick=()=>setZoom(state.zoom*1.3);$('#zoom-out').onclick=()=>setZoom(state.zoom/1.3);
function options() {
  const select=$('#captures');select.replaceChildren();const list=[...state.captures];
  if(state.capture&&!list.some(x=>x.id===state.capture.id))list.unshift(state.capture);
  if(!state.capture){const option=document.createElement('option');option.value='';option.textContent=list.length?'Open a previous screenshot…':'No screenshots yet';select.append(option);}
  for(const capture of list){const option=document.createElement('option');option.value=capture.id;option.textContent=(capture.saved?'✓ ':'')+capture.title;select.append(option);}
  select.value=state.capture?state.capture.id:'';
}
function clearWorkspace() {
  // Clear only the viewing surface. Saved PNGs and editable drafts stay intact.
  persist();loadSerial++;state.capture=null;state.image=null;state.strokes=[];state.redo=[];state.active=null;
  state.dirty=false;state.manual=false;state.pending=null;state.submission=null;state.queue=[];
  pointers.clear();pan=null;pinch=null;canvas.width=1;canvas.height=1;
  $('#original').removeAttribute('src');paper.hidden=true;$('#empty').hidden=false;
  $('#new-capture').hidden=true;$('#dimensions').textContent='';$('#fit').textContent='Fit';
  try{localStorage.setItem('screenshot-current','');localStorage.setItem('screenshot-queue','[]');}catch{}
  options();updateButtons();
}
async function load(capture) {
  persist();state.lastCopied=null;$('#complete').hidden=true;const serial=++loadSerial;state.image=null;updateButtons();status('Opening screenshot…');
  const image=new Image();image.src='/api/image/'+capture.id;
  try{await image.decode();if(serial!==loadSerial)return;
    if(image.naturalWidth*image.naturalHeight>16000000)throw Error('This screenshot is too large for iPad drawing. Capture a smaller area on your Mac.');
    state.capture=capture;state.image=image;state.strokes=[];state.redo=[];state.active=null;pointers.clear();pan=null;pinch=null;state.dirty=false;state.submission=null;state.pending=null;$('#new-capture').hidden=true;
    try{localStorage.setItem('screenshot-current',capture.id);}catch{}
    try{const draft=JSON.parse(localStorage.getItem('screenshot-draft-'+capture.id));if(draft&&Array.isArray(draft.strokes)){state.strokes=draft.strokes;state.dirty=!!draft.dirty;}}catch{}
    $('#original').src=image.src;canvas.width=capture.width;canvas.height=capture.height;paper.hidden=false;$('#empty').hidden=true;$('#dimensions').textContent=capture.width+' × '+capture.height;
    options();fit();render();updateButtons();status(state.dirty?'Your unfinished drawing is restored.':'Use Pencil to draw. Use a finger to move around.');return true;
  }catch(error){if(serial===loadSerial){status(error.message||'Could not open the screenshot. Check your connection.','error');updateButtons();}}
}
$('#captures').onchange=()=>{const capture=state.captures.find(x=>x.id===$('#captures').value);if(capture){state.manual=true;load(capture);}};
$('#new-capture').onclick=()=>{if(state.pending){state.manual=false;load(state.pending);}};
async function refresh() {
  if(pollBusy||state.saving)return;pollBusy=true;const revision=libraryRevision;
  try {
    const result=await api('/api/library');if(revision!==libraryRevision||state.saving)return;$('#pairing').hidden=true;$('#connection').textContent='Connected to your Mac';
    state.captures=result.captures;syncQueue();options();const next=waiting()[0];
    if(!state.capture&&!state.saving){
      let restored;try{const id=localStorage.getItem('screenshot-current');const draft=JSON.parse(localStorage.getItem('screenshot-draft-'+id));restored=state.captures.find(c=>c.id===id&&(draft?.dirty||!c.saved));}catch{}
      const first=restored||next;if(first)await load(first);
      else if(!state.lastCopied&&$('#complete').hidden)status('Ready for your next screenshot. Finished images are saved on your Mac.');
    } else if(next&&next.id!==state.capture?.id){
      const current=state.captures.find(c=>c.id===state.capture?.id);
      if(state.dirty||state.active||state.saving||state.manual||!current?.saved){state.pending=next;$('#new-capture').hidden=!state.manual;}
      else await load(next);
    }
    if(state.lastCopied){const copy=await api('/api/status');if(copy.lastCopied===state.lastCopied){status('Copied on Mac — paste into your agent.','success');if(!state.dirty&&!state.active){
      const count=state.finishedCount;
      $('#complete-title').textContent=count>1?'All '+count+' screenshots saved.':'Ready to paste.';
      $('#complete-detail').textContent=count>1?'All '+count+' annotated PNGs are in Documents → Screenshot Tool → Ready on your Mac. Drag them together into your agent. ⌘V pastes only the last image.':'Go to your agent on the Mac and press ⌘V. Your annotated PNG is also saved in Documents → Screenshot Tool → Ready.';
      $('#complete').hidden=false;
    }state.lastCopied=null;}}
  } catch(error){$('#connection').textContent='Mac connection unavailable';if(state.capture)status('Connection interrupted. Your drawing is kept here; reconnect and tap Done.','error');}
  finally{pollBusy=false;}
}
async function done() {
  if(!state.image||state.saving)return;
  if(state.active){const {id,pointerType,...stroke}=state.active;state.strokes.push(stroke);state.active=null;changed();}
  state.saving=true;$('#complete').hidden=true;document.body.classList.add('saving');$('#done').textContent='Creating image…';updateButtons();status('Creating your finished image…');
  let exportCanvas;
  try {
    render();exportCanvas=document.createElement('canvas');exportCanvas.width=canvas.width;exportCanvas.height=canvas.height;const c=exportCanvas.getContext('2d');if(!c)throw Error('Not enough drawing memory. Your marks are saved here; refresh this page and try Done again.');c.drawImage(state.image,0,0);c.drawImage(canvas,0,0);
    const blob=await new Promise((resolve,reject)=>{
      const timeout=setTimeout(()=>reject(Error('Creating the image took too long. Your drawing is kept here. Try Done again.')),15000);
      try{exportCanvas.toBlob(b=>{clearTimeout(timeout);b?resolve(b):reject(Error('Could not export this image. Try a smaller capture.'));},'image/png');}catch(error){clearTimeout(timeout);reject(error);}
    });
    exportCanvas.width=1;exportCanvas.height=1;state.submission??=uuid();$('#done').textContent='Sending to Mac…';status('Sending your marked-up image to the Mac…');
    const result=await api('/api/save',{method:'POST',headers:{'Content-Type':'image/png','X-Capture-ID':state.capture.id,'X-Submission-ID':state.submission},body:blob});
    await saved(result);
  } catch(error){status(error.message||'Save failed. Your drawing is still here. Tap Done to retry.','error');}
  finally{if(exportCanvas){exportCanvas.width=1;exportCanvas.height=1;}state.saving=false;document.body.classList.remove('saving');$('#done').textContent='Done ↗';updateButtons();refresh();}
}
async function saved(result) {
  libraryRevision++;
  const capture=state.captures.find(c=>c.id===state.capture.id);if(capture)capture.saved=true;
  state.capture.saved=true;state.dirty=false;persist();options();state.manual=false;
  const next=waiting()[0];
  if(next){if(await load(next))status('Previous image saved on Mac. Annotate this screenshot, then tap Done.','success');}
  else{state.finishedCount=Math.max(1,state.queue.filter(id=>state.captures.some(c=>c.id===id&&c.saved)).length);clearWorkspace();state.lastCopied=result.id;status('Saved on Mac. Waiting for the clipboard…','success');}
}
$('#done').onclick=done;$('#try-again').onclick=refresh;
window.addEventListener('pagehide',persist);document.addEventListener('visibilitychange',()=>{persist();if(!document.hidden)refresh();});
window.addEventListener('resize',()=>{if(!state.active)fit();});
async function start() {
  const token=new URLSearchParams(location.hash.slice(1)).get('pair');
  if(token){history.replaceState(null,'',location.pathname);try{await api('/api/pair',{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:'{}'});}catch(error){status(error.message,'error');}}
  await refresh();setInterval(refresh,2000);
}
start();
