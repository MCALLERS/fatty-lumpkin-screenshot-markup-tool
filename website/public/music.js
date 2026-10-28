/* Local narration and an original Web Audio score, enabled by default.
   Browsers may hold AudioContext suspended until a real click or key press. */
(() => {
  'use strict';
  const button = document.getElementById('film-music');
  if (!button) return;
  const starts = [0, 5, 9, 15, 22, 30];
  const narrationEnabled = button.dataset.narration === 'ready';
  let context, musicBus, voiceBus, enabled = true, blocked = false, pageActive = true;
  let state = { time: 0, playing: false }, lastTime = 0, wasPlaying = false;
  let scheduled = new Set(), active = [], voice = null, buffers = [], generation = 0;
  const notes = [], requests = [];
  const chords = [[48,55,60,64,69],[45,52,57,60,64],[41,48,53,57,60],[43,50,55,59,62]];
  for (let bar = 0; bar < 12; bar++) {
    const chord = chords[bar % chords.length];
    notes.push({ time: bar * 3, midi: chord[0], length: 2.7, volume: .14 });
    [0,.75,1.5,2.25].forEach((offset,step) => notes.push({time:bar*3+offset,midi:chord[[2,3,4,3][step]]+(bar>7?12:0),length:1.7,volume:step===0?.12:.085}));
  }
  notes.sort((a,b) => a.time-b.time);
  function label() {
    button.textContent = !enabled ? '♫ Sound off' : blocked ? '▶ Enable sound' : '♫ Sound on';
    button.setAttribute('aria-pressed', String(enabled && !blocked));
    button.title = blocked ? 'Your browser needs a click to start sound' : narrationEnabled ? 'Narration and background music' : 'Background music';
  }
  function stopVoice() {
    if (voice) { try { voice.source.stop(); } catch (_) {} voice.source.disconnect(); voice = null; }
  }
  function silence() {
    stopVoice();
    if (context) for (const item of active) {
      try { item.gain.gain.cancelScheduledValues(context.currentTime); item.gain.gain.setTargetAtTime(0,context.currentTime,.018); item.oscillators.forEach(osc=>osc.stop(context.currentTime+.08)); } catch (_) {}
    }
    active=[]; scheduled.clear(); wasPlaying=false;
  }
  function ensureContext() {
    if (context && context.state !== 'closed') return;
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) throw new Error('Audio unavailable');
    context = new Audio(); const instance = context, epoch = ++generation;
    musicBus=context.createGain(); musicBus.gain.value=.30; musicBus.connect(context.destination);
    voiceBus=context.createGain(); voiceBus.gain.value=.9; voiceBus.connect(context.destination);
    buffers=[];
    context.addEventListener('statechange',()=>{
      if(instance!==context)return;
      blocked=enabled && context.state!=='running'; label();
      if(context.state==='running') sync(state); else silence();
    });
    if(narrationEnabled) starts.forEach((_,index)=>{
      requests[index] ||= fetch(`/assets/audio/narration-${String(index+1).padStart(2,'0')}.mp3`).then(response=>{
        if(!response.ok)throw new Error('Narration unavailable'); return response.arrayBuffer();
      });
      requests[index].then(bytes=>instance.decodeAudioData(bytes.slice(0))).then(buffer=>{
        if(epoch!==generation)return; buffers[index]=buffer; sync(state);
      }).catch(()=>{ /* Music and the written transcript remain available. */ });
    });
    blocked=context.state!=='running'; label();
  }
  function tone(note,when) {
    const gain=context.createGain(), fundamental=context.createOscillator(), overtone=context.createOscillator(), color=context.createGain();
    const frequency=440*Math.pow(2,(note.midi-69)/12);
    fundamental.type='sine'; fundamental.frequency.value=frequency;
    overtone.type='sine'; overtone.frequency.value=frequency*2; overtone.detune.value=1.2;
    color.gain.value=.13; fundamental.connect(gain); overtone.connect(color); color.connect(gain); gain.connect(musicBus);
    gain.gain.setValueAtTime(0,when); gain.gain.linearRampToValueAtTime(note.volume,when+.022); gain.gain.exponentialRampToValueAtTime(.001,when+note.length);
    fundamental.start(when); overtone.start(when); fundamental.stop(when+note.length+.04); overtone.stop(when+note.length+.04);
    overtone.onended=()=>{fundamental.disconnect();overtone.disconnect();color.disconnect();gain.disconnect();};
    active.push({gain,oscillators:[fundamental,overtone],end:when+note.length+.05});
  }
  function narrate(time) {
    const index=starts.findLastIndex(start=>time>=start), buffer=buffers[index], offset=time-starts[index];
    if(!buffer || offset>=buffer.duration || time>=36){stopVoice();return false;}
    const drift=voice?Math.abs((context.currentTime-voice.clock)+voice.time-time):0;
    if(voice?.index!==index || drift>.18) {
      stopVoice(); const source=context.createBufferSource(); source.buffer=buffer; source.connect(voiceBus);
      source.start(context.currentTime,Math.max(0,offset));
      voice={source,index,clock:context.currentTime,time};
    }
    return true;
  }
  function sync(next) {
    state=next;
    if(!enabled || !pageActive || document.hidden || !next.playing){silence();lastTime=next.time;return;}
    if(!context || context.state!=='running')return;
    if(Math.abs(next.time-lastTime)>.4 || next.time<lastTime-.02 || !wasPlaying)silence();
    const speaking=narrationEnabled && narrate(next.time);
    musicBus.gain.setTargetAtTime(speaking?.10:.30,context.currentTime,.12);
    active=active.filter(item=>item.end>context.currentTime);
    for(let i=0;i<notes.length;i++) {
      const delta=notes[i].time-next.time;
      if(delta>=-.035 && delta<=.22 && !scheduled.has(i)){tone(notes[i],context.currentTime+Math.max(.012,delta));scheduled.add(i);}
    }
    lastTime=next.time;wasPlaying=true;
  }
  function unlock() {
    if(!enabled)return;
    try {
      ensureContext();
      // Do not await: a browser can leave this promise pending until a gesture.
      if(context.state==='suspended')context.resume().then(()=>{blocked=false;label();sync(state);}).catch(()=>{blocked=true;label();});
      else sync(state);
    } catch(_){enabled=false;silence();label();button.textContent='Sound unavailable';button.disabled=true;}
  }
  button.addEventListener('click',()=>{
    if(enabled && blocked){unlock();return;}
    enabled=!enabled;
    if(enabled)unlock();else silence();label();
  });
  const gesture=event=>{if(!event.target.closest?.('#film-music') && enabled)unlock();};
  document.addEventListener('pointerdown',gesture,{passive:true});
  document.addEventListener('keydown',event=>{if(!event.metaKey&&!event.ctrlKey&&!event.altKey)gesture(event);});
  window.addEventListener('ludwig:film-state',event=>sync(event.detail));
  document.addEventListener('visibilitychange',()=>{if(document.hidden)silence();});
  window.addEventListener('pagehide',event=>{
    pageActive=false;silence();
    if(!event.persisted && context && context.state!=='closed')context.close().catch(()=>{});
  });
  window.addEventListener('pageshow',event=>{pageActive=true;if(event.persisted)unlock();});
  label(); unlock();
})();
