/* Ludwig's illustrated workflow. All imagery stays local; this is not an AI integration. */
(() => {
  'use strict';
  const canvas = document.getElementById('workflow-film');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const W = 1280, H = 800, DURATION = 36;
  const C = { paper: '#f2eadc', ink: '#202824', red: '#d34c37', sage: '#64836e', muted: '#78796e', line: '#d6cebf', white: '#fffdf7' };
  const ui = {
    stage: document.getElementById('film-stage'), toggle: document.getElementById('film-toggle'),
    replay: document.getElementById('film-replay'), seek: document.getElementById('film-seek'),
    time: document.getElementById('film-time'), caption: document.getElementById('film-caption'),
    scenes: [...document.querySelectorAll('[data-film-scene]')]
  };
  const starts = [0, 5, 9, 15, 22, 30];
  const stills = [3.8, 7.8, 13.5, 20.5, 28.3, 35.0];
  const captions = [
    '01 / Typed prompts and voice notes can leave the reference unclear. Which button?',
    '02 / Start with a picture. Show your AI what you mean.',
    '03 / Capture an example on your Mac. Bring it to your iPad.',
    '04 / Write a grade, circle the detail, and explain your judgment.',
    '05 / Tap Done on iPad. On your Mac, press Command-V in your chosen chat. Then send.',
    '06 / Your annotated image carries your feedback. Review the revision, then repeat.'
  ];
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const motionAllowed = window.LudwigMotion?.allowed ?? !reduce.matches;
  const portrait = new Image();
  let t = motionAllowed ? 0 : 20.5, playing = motionAllowed, frame = 0, last = null;
  let inView = true, captionIndex = -1;
  const clamp = (n, a = 0, b = 1) => Math.max(a, Math.min(b, n));
  const ease = n => 1 - Math.pow(1 - clamp(n), 3);
  const phase = (n, a, b) => ease((n - a) / (b - a));
  const mix = (a, b, n) => a + (b - a) * n;
  const sceneAt = time => { let index = 0; while (index < starts.length - 1 && time >= starts[index + 1]) index++; return index; };
  function rounded(x, y, w, h, r = 12, fill, stroke) {
    ctx.beginPath(); ctx.roundRect(x, y, w, h, r);
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
  }
  function text(value, x, y, size = 20, color = C.ink, family = 'sans', weight = 400) {
    ctx.fillStyle = color;
    ctx.font = `${weight} ${size}px ${family === 'serif' ? '"Bodoni Moda", Georgia, serif' : family === 'hand' ? '"Bodoni Moda", Georgia, serif' : '"Instrument Sans", Arial, sans-serif'}`;
    if (family === 'hand') ctx.font = `italic ${size}px "Bodoni Moda", Georgia, serif`;
    ctx.fillText(value, x, y);
  }
  function line(x1, y1, x2, y2, color = C.line, width = 1) {
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.strokeStyle = color; ctx.lineWidth = width; ctx.stroke();
  }
  function fade(alpha, draw) { ctx.save(); ctx.globalAlpha *= clamp(alpha); draw(); ctx.restore(); }
  function shadow(draw, blur = 30, alpha = .13) {
    ctx.save(); ctx.shadowColor = `rgba(32,40,36,${alpha})`; ctx.shadowBlur = blur; ctx.shadowOffsetY = 16; draw(); ctx.restore();
  }
  function paperStrip(x, y, w, h, angle = 0, color = C.white) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(angle);
    shadow(() => {
      ctx.beginPath(); ctx.moveTo(0, 2); ctx.lineTo(w * .38, 0); ctx.lineTo(w, 3); ctx.lineTo(w - 2, h);
      ctx.lineTo(w * .58, h - 1); ctx.lineTo(2, h + 1); ctx.closePath(); ctx.fillStyle = color; ctx.fill();
    }, 7, .065); ctx.restore();
  }
  function tape(x, y, angle = -.06) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(angle); ctx.globalAlpha *= .65;
    ctx.fillStyle = '#d7c69c'; ctx.fillRect(-46, -12, 92, 24);
    line(-44, -9, 43, -9, '#e7dab9'); line(-44, 9, 43, 9, '#c9ba91'); ctx.restore();
  }
  function stroke(points, progress = 1, color = C.red, width = 4) {
    if (progress <= 0) return;
    const steps = points.length - 1, edge = clamp(progress) * steps, whole = Math.floor(edge);
    ctx.beginPath(); ctx.moveTo(...points[0]);
    for (let i = 1; i <= Math.min(whole, steps); i++) ctx.lineTo(...points[i]);
    if (whole < steps) ctx.lineTo(mix(points[whole][0], points[whole + 1][0], edge - whole), mix(points[whole][1], points[whole + 1][1], edge - whole));
    ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.strokeStyle = color; ctx.lineWidth = width; ctx.stroke();
  }
  function ellipseStroke(x, y, rx, ry, p, color = C.red) {
    const points = Array.from({ length: 65 }, (_, i) => {
      const a = i / 64 * Math.PI * 2.1 - .3;
      return [x + Math.cos(a) * (rx + Math.sin(a * 3) * 3), y + Math.sin(a) * ry];
    });
    stroke(points, p, color, 3.2);
    return pointOnPath(points, p);
  }
  function pointOnPath(points, p) {
    const step = clamp(p) * (points.length - 1), i = Math.min(Math.floor(step), points.length - 2), part = step - i;
    return [mix(points[i][0], points[i + 1][0], part), mix(points[i][1], points[i + 1][1], part)];
  }
  function writeNote(value, x, y, p, color = C.red, size = 24) {
    ctx.save(); ctx.font = `italic ${size}px "Bodoni Moda", Georgia, serif`;
    const width = ctx.measureText(value).width;
    ctx.beginPath(); ctx.rect(x - 3, y - size * 1.25, (width + 9) * clamp(p), size * 1.7); ctx.clip();
    text(value, x, y, size, color, 'hand'); ctx.restore(); return [x + width * clamp(p), y - 3];
  }
  function grade(x, y, size, label, p = 1, color = C.red) {
    ctx.save(); ctx.translate(x, y); ctx.scale(size / 60, size / 60); ctx.rotate(-.06);
    if (label.startsWith('B')) {
      stroke([[0, 0], [1, -48], [15, -52], [30, -47], [32, -36], [24, -27], [6, -25], [27, -25], [37, -15], [34, -5], [20, 1], [1, 0]], p, color, 3.7);
    } else {
      stroke([[0, 1], [20, -51], [25, -51], [43, 0]], p, color, 3.7);
      stroke([[10, -20], [34, -21]], phase(p, .55, .85), color, 3.7);
    }
    stroke([[49, -25], [69, -25]], phase(p, .65, .9), color, 3.4);
    if (label.includes('+')) stroke([[59, -35], [59, -15]], phase(p, .8, 1), color, 3.4);
    ctx.restore();
  }
  function pencil(x, y, angle = -.65) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(angle);
    shadow(() => rounded(-6, -171, 12, 153, 5, C.white, '#c4bdaf'), 9, .16);
    ctx.beginPath(); ctx.moveTo(-6, -18); ctx.lineTo(0, 0); ctx.lineTo(6, -18); ctx.closePath(); ctx.fillStyle = '#c6b7a1'; ctx.fill();
    ctx.beginPath(); ctx.moveTo(-2, -6); ctx.lineTo(0, 0); ctx.lineTo(2, -6); ctx.closePath(); ctx.fillStyle = C.ink; ctx.fill();
    ctx.restore();
  }
  function heading(number, title, subtitle) {
    text('Ludwig’s Annotated Screenshots', 68, 54, 15, C.muted, 'sans', 500);
    ctx.textAlign = 'right'; text(`${number} / 06`, 1212, 54, 14, C.muted); ctx.textAlign = 'left';
    line(68, 74, 1212, 74);
    text(title, 68, 134, 42, C.ink, 'serif');
    if (subtitle) text(subtitle, 70, 169, 18, C.muted);
  }
  function architecture(x, y, w, h, calm) {
    ctx.save(); ctx.beginPath(); ctx.rect(x, y, w, h); ctx.clip();
    ctx.fillStyle = calm ? '#c4cbbd' : '#c7b4cc'; ctx.fillRect(x, y, w, h);
    ctx.fillStyle = calm ? '#e7dfcb' : '#e9bc80'; ctx.fillRect(x + w * .16, y + h * .2, w * .64, h);
    ctx.fillStyle = calm ? '#8b9a86' : '#d07861'; ctx.fillRect(x + w * .65, y + h * .2, w * .15, h);
    ctx.fillStyle = calm ? '#73836c' : '#755881'; ctx.fillRect(x + w * .31, y + h * .43, w * .18, h * .58);
    ctx.fillStyle = calm ? '#d1d3ba' : '#e1aa73'; ctx.beginPath(); ctx.moveTo(x, y + h); ctx.lineTo(x + w * .16, y + h * .7); ctx.lineTo(x + w * .65, y + h * .7); ctx.lineTo(x + w, y + h); ctx.fill();
    ctx.restore();
  }
  // Shared, intentionally illustrative interface used throughout the six shots.
  function screen(x, y, w, h, { calm = false, annotations = 0, chrome = true, border = true, activePencil = false } = {}) {
    ctx.save(); ctx.translate(x, y); ctx.scale(w / 800, h / 500);
    rounded(0, 0, 800, 500, 14, C.white, border ? C.line : undefined);
    ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0;
    ctx.save(); ctx.beginPath(); ctx.roundRect(0, 0, 800, 500, 14); ctx.clip();
    ctx.fillStyle = '#ebe7dd'; ctx.fillRect(0, 0, 800, 36);
    if (chrome) {
      ['#d18b78', '#d7bd80', '#9cab8d'].forEach((c, i) => { ctx.beginPath(); ctx.arc(19 + i * 17, 18, 4, 0, Math.PI * 2); ctx.fillStyle = c; ctx.fill(); });
      text('Fieldnotes — a work in progress', 272, 23, 11, C.muted);
    }
    ctx.fillStyle = '#f0eee6'; ctx.fillRect(0, 36, 150, 464);
    text('f.', 24, 90, 39, C.ink, 'serif');
    text('FIELDNOTES', 25, 119, 9, C.muted, 'sans', 600);
    ['Overview', 'Your collection', 'Inspiration', 'Notes'].forEach((v, i) => {
      if (i === 1) rounded(14, 143 + i * 35, 123, 28, 5, '#dfe4d8');
      text(v, 25, 162 + i * 35, 11, i === 1 ? C.ink : C.muted, 'sans', i === 1 ? 600 : 400);
    });
    text('A small place for', 25, 447, 10, C.muted); text('unfinished thoughts.', 25, 462, 10, C.muted);
    text('YOUR COLLECTION', 184, 79, 10, C.muted, 'sans', 500);
    text('A place for better ideas.', 184, 127, 33, C.ink, 'serif');
    text('The things worth keeping. The ideas worth pursuing.', 185, 152, 12, C.muted);
    rounded(184, 180, 373, 229, 8, '#f8f5ed', C.line);
    architecture(195, 191, 351, 145, calm);
    text('Spaces to think', 199, 365, 18, C.ink, 'serif');
    text('A collection of quieter corners.', 199, 386, 11, C.muted);
    rounded(575, 180, 188, 229, 8, calm ? '#e5e9df' : '#e6d3c4');
    text('01 / A NOTE', 593, 208, 9, C.muted, 'sans', 600);
    text('Leave room', 593, 250, 25, C.ink, 'serif'); text('for the idea.', 593, 281, 25, C.ink, 'serif');
    line(593, 307, 741, 307, calm ? '#bdc7b7' : '#caa58c');
    text('Less competing.', 593, 333, 11, C.muted); text('More belonging.', 593, 352, 11, C.muted);
    text('12 saved thoughts', 185, 453, 11, C.muted);
    rounded(615, 431, 149, 35, 5, calm ? C.sage : C.red);
    text('Add an idea  +', 638, 453, 12, C.white, 'sans', 500);
    let tip = null;
    if (annotations > 0) {
      const ink = calm ? C.sage : C.red, gp = clamp(annotations / .18);
      grade(675, 145, 45, calm ? 'A−' : 'B+', gp, ink);
      if (gp > 0 && gp < 1) tip = pointOnPath([[676, 145], [676, 108], [690, 107], [701, 118], [682, 125], [706, 133], [691, 145], [675, 145], [721, 127], [726, 127]], gp);
      const ring = clamp((annotations - .2) / .22);
      const ringTip = ellipseStroke(calm ? 366 : 375, calm ? 159 : 266, calm ? 201 : 181, calm ? 20 : 85, ring, ink);
      if (ring > 0 && ring < 1) tip = ringTip;
      const reason = clamp((annotations - .44) / .2);
      const reasonTip = writeNote(calm ? 'keep this spacing' : 'colors compete', 218, 430, reason, ink, 25);
      if (reason > 0 && reason < 1) tip = reasonTip;
      const good = clamp((annotations - .66) / .16);
      const goodTip = writeNote(calm ? 'calm palette' : 'good structure', 580, 390, good, ink, 21);
      if (good > 0 && good < 1) tip = goodTip;
      if (!calm) {
        const button = clamp((annotations - .83) / .07);
        const buttonTip = ellipseStroke(689, 449, 86, 27, button, ink);
        if (button > 0 && button < 1) tip = buttonTip;
        const label = clamp((annotations - .91) / .09);
        const labelTip = writeNote('quieter button', 577, 489, label, ink, 22);
        if (label > 0 && label < 1) tip = labelTip;
      }
    }
    ctx.restore();
    if (activePencil && tip) pencil(tip[0], tip[1], -.36);
    ctx.restore();
  }
  function tablet(x, y, w, h, { progress = 0, activePencil = false, done = 0, loaded = 1 } = {}) {
    shadow(() => rounded(x, y, w, h, 27, C.ink), 38, .2);
    rounded(x + 12, y + 12, w - 24, h - 24, 18, C.white);
    text('Ludwig’s Annotated Screenshots', x + 27, y + 39, w < 450 ? 9 : 12, C.muted);
    rounded(x + w - 82, y + 22, 59, 27, 13, done > .2 ? C.sage : '#e7eee4');
    text(done > .2 ? 'Done ✓' : 'Done', x + w - 72, y + 40, 12, done > .2 ? C.white : C.sage, 'sans', 600);
    const screenH = Math.min((w - 48) * .625, h - 110), screenW = screenH / .625;
    fade(1 - loaded, () => text('Ready for your screenshot.', x + 39, y + h / 2, 18, C.muted, 'serif'));
    fade(loaded, () => screen(x + (w - screenW) / 2, y + 61, screenW, screenH, { annotations: progress, activePencil }));
    const py = y + h - 29;
    rounded(x + w / 2 - 95, py - 17, 190, 32, 16, '#ece9df');
    [C.red, C.ink, C.sage, '#d3ab55'].forEach((c, i) => { ctx.beginPath(); ctx.arc(x + w / 2 - 43 + i * 25, py - 1, 5, 0, 7); ctx.fillStyle = c; ctx.fill(); });
    line(x + w / 2 - 70, py + 7, x + w / 2 - 66, py - 9, C.ink, 3);
    return { x: x + (w - screenW) / 2, y: y + 61, w: screenW, h: screenH, doneX: x + w - 53, doneY: y + 35 };
  }
  function monitor(x, y, w, content) {
    const iw = w - 28, ih = iw * .625;
    shadow(() => rounded(x, y, w, ih + 57, 18, '#383e39'), 28, .16);
    rounded(x + 1, y + ih + 22, w - 2, 34, [0, 0, 17, 17], '#d9d9d1');
    ctx.beginPath(); ctx.moveTo(x + w / 2 - 24, y + ih + 57); ctx.lineTo(x + w / 2 + 24, y + ih + 57);
    ctx.lineTo(x + w / 2 + 34, y + ih + 94); ctx.lineTo(x + w / 2 - 34, y + ih + 94); ctx.closePath();
    ctx.fillStyle = '#bcbfb7'; ctx.fill(); rounded(x + w / 2 - 98, y + ih + 92, 196, 9, 5, '#aeb3aa');
    const area = { x: x + 14, y: y + 14, w: iw, h: ih };
    content(area); return area;
  }
  function pointer(x, y, click = 0, finger = false) {
    if (click > 0 && click < 1) fade(1 - click, () => {
      ctx.beginPath(); ctx.arc(x, y, 14 + click * 22, 0, Math.PI * 2); ctx.strokeStyle = C.red; ctx.lineWidth = 2; ctx.stroke();
    });
    ctx.save(); ctx.translate(x, y);
    if (finger) {
      rounded(-8, -4, 16, 35, 8, '#ecd2b8', '#a99177');
      rounded(-7, 15, 29, 27, 9, '#ecd2b8', '#a99177');
    } else {
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(4, 23); ctx.lineTo(10, 17); ctx.lineTo(15, 26);
      ctx.lineTo(20, 23); ctx.lineTo(15, 15); ctx.lineTo(23, 12); ctx.closePath();
      ctx.fillStyle = C.white; ctx.fill(); ctx.strokeStyle = C.ink; ctx.lineWidth = 1.5; ctx.stroke();
    }
    ctx.restore();
  }
  function shortcut(x, y, key, label, press = 0) {
    rounded(x, y, 117, 37, 7, press > 0 && press < 1 ? C.ink : '#e4ddcf', '#d5cdbc');
    text(key, x + 22, y + 26, 22, press > 0 && press < 1 ? C.white : C.ink);
    text(label, x + 135, y + 25, 17, C.muted);
  }
  function chat(x, y, w, h, { mode = 'compose', local = 0, pasted = 0, sent = 0 } = {}) {
    ctx.save(); ctx.translate(x, y); ctx.scale(w / 800, h / 500);
    rounded(0, 0, 800, 500, 10, C.white, C.line);
    ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0;
    rounded(0, 0, 800, 35, [10, 10, 0, 0], '#e9e7df');
    ['#d18b78', '#d7bd80', '#9cab8d'].forEach((c, i) => { ctx.beginPath(); ctx.arc(18 + i * 16, 17, 4, 0, 7); ctx.fillStyle = c; ctx.fill(); });
    text('Your chosen chat', 331, 23, 12, C.muted);
    ctx.fillStyle = '#efeee7'; ctx.fillRect(0, 35, 153, 465);
    text('Conversations', 20, 76, 13, C.ink, 'sans', 500);
    rounded(12, 95, 130, 37, 7, '#dde4d8'); text('Visual feedback', 22, 118, 11, C.ink);
    ['New idea', 'Today’s work', 'Earlier thoughts'].forEach((v, i) => text(v, 22, 162 + i * 30, 11, C.muted));
    text('YOUR CONVERSATION', 180, 66, 11, C.muted, 'sans', 500);
    if (mode === 'confusion') {
      const lines = [
        { y: 91, x: 284, w: 487, value: 'Move that button…', who: 'YOU', delay: 0 },
        { y: 172, x: 179, w: 459, value: 'Which one?', who: 'AI', delay: .6 },
        { y: 253, x: 284, w: 487, value: 'No, the other one.', who: 'YOU', delay: 1.2 }
      ];
      lines.forEach(row => fade(row.delay ? phase(local, row.delay, row.delay + .4) : 1, () => {
        rounded(row.x, row.y, row.w, 65, 10, row.who === 'YOU' ? '#e7ebdf' : '#f2eee6');
        text(row.who, row.x + 17, row.y + 20, 9, C.muted, 'sans', 500);
        text(row.value, row.x + 17, row.y + 47, 30, C.ink, 'serif');
      }));
      rounded(179, 346, 591, 126, 10, '#faf8f2', C.line);
      fade(phase(local, 1.9, 2.5), () => {
        text('VOICE NOTE', 198, 370, 10, C.muted);
        for (let i = 0; i < 58; i++) {
          const amp = 4 + Math.abs(Math.sin(i * 1.7 + local * 2.2) * Math.sin(i * .3 - local)) * 24;
          line(201 + i * 8.8, 403 - amp / 2, 201 + i * 8.8, 403 + amp / 2, i < 27 ? C.red : '#aaa89b', 2.2);
        }
        text('Another way to explain the same thing.', 198, 449, 13, C.muted);
      });
    } else if (mode === 'received') {
      text('YOU', 194, 103, 10, C.muted, 'sans', 500);
      rounded(189, 118, 581, 317, 11, '#e8eddf');
      screen(205, 135, 349, 218, { annotations: 1 });
      text('annotated-screenshot.png', 568, 177, 10, C.muted);
      text('PNG', 568, 200, 10, C.sage, 'sans', 500);
      text('Keep the layout. Calm the colors.', 208, 385, 21, C.ink);
      text('Your feedback is in the conversation.', 192, 471, 15, C.muted);
    } else {
      text('What would you change?', 181, 111, 25, C.ink, 'serif');
      rounded(178, 146, 594, 321, 11, '#faf8f2', C.line);
      fade(1 - pasted, () => text('Paste your annotated screenshot here…', 199, 190, 17, C.muted));
      fade(pasted, () => {
        screen(198, 165, 306, 191, { annotations: 1 });
        text('annotated-', 521, 206, 14, C.muted); text('screenshot.png', 521, 226, 14, C.muted);
        text('Your marks.', 521, 272, 18, C.ink, 'serif'); text('Your reasons.', 521, 297, 18, C.ink, 'serif');
        text('Keep the layout. Calm the colors.', 199, 393, 20, C.ink);
      });
      const pulse = Math.sin(clamp((local - 6.15) / .24) * Math.PI);
      ctx.save(); ctx.translate(740, 434); ctx.scale(1 - pulse * .12, 1 - pulse * .12);
      rounded(-17, -17, 34, 34, 17, sent > .5 ? C.sage : C.ink);
      stroke(sent > .5 ? [[-7, 0], [-2, 5], [7, -5]] : [[0, 7], [0, -6], [-6, 0], [0, -6], [6, 0]], 1, C.white, 1.8); ctx.restore();
      fade(sent, () => text('Sent by you', 199, 439, 13, C.sage, 'sans', 500));
    }
    ctx.restore();
  }
  function referencePhone(x, y, p) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(.018);
    shadow(() => rounded(0, 0, 279, 477, 31, C.ink), 27, .16);
    rounded(10, 11, 259, 455, 24, C.white); rounded(99, 17, 81, 15, 8, C.ink);
    text('REFERENCE IMAGE', 31, 60, 10, C.muted, 'sans', 500);
    text('A quieter place', 29, 103, 28, C.ink, 'serif'); text('for better ideas.', 29, 136, 28, C.ink, 'serif');
    architecture(28, 162, 223, 147, true);
    text('Spaces to think', 29, 339, 20, C.ink, 'serif');
    grade(191, 70, 39, 'A−', phase(p, 0, .3), C.sage);
    writeNote('calm palette', 33, 382, phase(p, .2, .7), C.sage, 25);
    writeNote('keep this', 33, 419, phase(p, .55, 1), C.sage, 25);
    ctx.restore();
    text('REFERENCE VIEW ONLY', x + 26, y + 508, 11, C.muted, 'sans', 500);
  }
  function confusion(local) {
    heading('01', '“No, the other one.”', 'The idea is clear in your head. The reference isn’t.');
    const settle = phase(local, 0, 1.5);
    monitor(61, 250 - settle * 8, 579, area => screen(area.x, area.y, area.w, area.h));
    ctx.save(); ctx.translate(669, 215 + (1 - settle) * 18);
    shadow(() => chat(0, 0, 548, 440, { mode: 'confusion', local }), 26, .13); ctx.restore();
    fade(phase(local, 1, 1.7), () => {
      ctx.save(); ctx.setLineDash([4, 7]); ctx.strokeStyle = '#9b9c90'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(674, 373); ctx.bezierCurveTo(610, 350, 657, 544, 571, 568); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(674, 373); ctx.bezierCurveTo(635, 369, 644, 288, 568, 290); ctx.stroke(); ctx.restore();
      text('?', 554, 566, 33, C.red, 'hand'); text('?', 561, 284, 33, C.red, 'hand');
    });
    fade(phase(local, 2.8, 3.5), () => {
      paperStrip(187, 716, 906, 51, -.008);
      text('The screenshot helps. Your marks make the point.', 226, 750, 28, C.ink, 'serif');
      stroke([[231, 758], [454, 760], [671, 755]], phase(local, 3.3, 4.2), C.red, 2.4);
    });
  }
  function intro(local) {
    const p = phase(local, 0, 4);
    heading('02', '', '');
    paperStrip(67, 146, 375, 107, -.016); paperStrip(65, 264, 518, 111, .012);
    text('Show,', 76, 232, 114, C.ink, 'serif'); text('don’t tell.', 76, 343, 114, C.ink, 'serif');
    ['Capture an example.', 'Mark what matters.', 'Paste it into your chat.'].forEach((value, i) => {
      const reveal = phase(local, .3 + i * .2, 1.2 + i * .2);
      fade(reveal, () => text(value, 82, 427 + i * 38 + (1 - reveal) * 9, 26, C.muted));
    });
    ctx.save();
    const characterDrawn = window.LudwigCharacter?.draw?.(ctx, { x: 594 - p * 9, y: 178, width: 666, time: local });
    if (!characterDrawn && portrait.complete && portrait.naturalWidth) {
      ctx.translate(601 - p * 10, 181 - p * 8); ctx.scale(1 + p * .025, 1 + p * .025);
      ctx.drawImage(portrait, 0, 0, 658, 493.5);
      stroke([[259, 434], [300, 407], [366, 411], [381, 443], [317, 451], [259, 434]], phase(local, 1.4, 3.1), C.red, 2.4);
    } else if (!characterDrawn) { text('Ludwig', 727, 394, 78, C.ink, 'serif'); text('meets the screenshot.', 696, 446, 28, C.muted, 'serif'); }
    ctx.restore();
    line(82, 589, 324, 589);
    text('A LITTLE EARLY WITTGENSTEIN.', 82, 621, 11, C.muted, 'sans', 500);
    text('Your judgment, in the margin.', 82, 654, 23, C.ink, 'serif');
    text('The picture starts the conversation.', 82, 744, 17, C.muted);
  }
  function capture(local) {
    heading('03', 'See it. Capture it.', 'Mac → iPad. The example comes with you.');
    const settle = phase(local, 1.4, 3.4), arrive = phase(local, 2.3, 3.85);
    const mx = mix(245, 64, settle), my = mix(190, 241, settle), mw = mix(790, 657, settle);
    const mac = monitor(mx, my, mw, area => screen(area.x, area.y, area.w, area.h));
    const crop = phase(local, .25, 1.2);
    fade((1 - phase(local, 1.4, 2.05)) * .95, () => {
      ctx.save(); ctx.setLineDash([9, 6]); ctx.lineWidth = 2; ctx.strokeStyle = C.red;
      ctx.strokeRect(mac.x + 22, mac.y + 30, (mac.w - 44) * crop, (mac.h - 49) * crop); ctx.restore();
      const cx = mac.x + 22 + (mac.w - 44) * crop, cy = mac.y + 30 + (mac.h - 49) * crop;
      line(cx - 14, cy, cx + 14, cy, C.red, 2); line(cx, cy - 14, cx, cy + 14, C.red, 2);
    });
    let target;
    fade(phase(local, 1.6, 2.65), () => {
      target = tablet(714, 235, 500, 435, { loaded: phase(local, 3.75, 4.05), progress: .38 * phase(local, 4.1, 5.6), activePencil: local > 4.1 && local < 5.7 });
    });
    if (target && local > 2.3 && local < 3.97) {
      const lift = Math.sin(arrive * Math.PI) * 65;
      shadow(() => screen(mix(mac.x, target.x, arrive), mix(mac.y, target.y, arrive) - lift, mix(mac.w, target.w, arrive), mix(mac.h, target.h, arrive)), 36, .19);
    }
    shortcut(82, 741, '⇧ ⌘ 4', local < 3.8 ? 'Capture the example.' : 'It is on your iPad. Make your point.', clamp((local - .7) / .5));
  }
  function annotate(local) {
    heading('04', 'Give it a grade. Give it a reason.', 'A+ to F. Your handwriting, your opinion, your why.');
    const drawn = .38 + .62 * clamp((local - .15) / 4.8), ref = phase(local, 1.45, 2.55);
    ctx.save(); ctx.translate(58, 220); ctx.rotate(-.008);
    tablet(0, 0, 821, 549, { progress: drawn, activePencil: local > .15 && local < 4.95 }); ctx.restore();
    fade(ref, () => referencePhone(920 + (1 - ref) * 34, 232 + (1 - ref) * 10, phase(local, 2.4, 4.5)));
  }
  function attach(local) {
    heading('05', 'Done on iPad. Paste on Mac.', 'The image is ready. You choose where it goes—and when to send it.');
    const focus = phase(local, 2.05, 3.45), pasted = phase(local, 4.05, 4.45), sent = phase(local, 6.2, 6.45);
    const mx = mix(551, 467, focus), my = mix(239, 209, focus), mw = mix(660, 747, focus);
    let mac;
    fade(mix(.35, 1, focus), () => { mac = monitor(mx, my, mw, area => chat(area.x, area.y, area.w, area.h, { pasted, sent, local })); });
    const tx = mix(69, 63, focus), ty = mix(221, 356, focus), tw = mix(668, 349, focus), th = mix(488, 288, focus);
    const pad = tablet(tx, ty, tw, th, { progress: 1, done: phase(local, 1.25, 1.5) });
    fade(phase(local, .35, .65) * (1 - phase(local, 1.65, 2.1)), () => {
      const move = phase(local, .4, 1.2);
      pointer(mix(pad.doneX + 58, pad.doneX, move), mix(pad.doneY + 118, pad.doneY, move), clamp((local - 1.2) / .45), true);
    });
    fade(phase(local, 1.5, 1.85), () => {
      const toastY = mix(720, 678, focus);
      shadow(() => rounded(65, toastY, 339, 58, 11, C.ink), 18, .1);
      text('✓', 85, toastY + 37, 25, '#c9dcc6'); text('Copied on your Mac', 121, toastY + 35, 20, C.white);
    });
    fade(phase(local, 3.45, 3.8), () => shortcut(65, 747, '⌘ V', 'Paste into your chat.', clamp((local - 3.8) / .45)));
    if (mac && local > 5.55) {
      const px = mac.x + mac.w * 740 / 800, py = mac.y + mac.h * 434 / 500, move = phase(local, 5.55, 6.17);
      fade(phase(local, 5.55, 5.85) * (1 - phase(local, 6.9, 7.35)), () => pointer(mix(px + 73, px, move), mix(py + 79, py, move), clamp((local - 6.17) / .4)));
    }
    fade(phase(local, 6.75, 7.25), () => {
      text('One now.', 76, 273, 32, C.ink, 'serif');
      text('A batch when you need it.', 76, 310, 24, C.muted, 'serif');
    });
  }
  function revision(local) {
    heading('06', 'Review. Refine. Repeat.', 'Your example, grade, and reasons arrive together.');
    const compare = phase(local, 1.05, 2.15);
    fade(1 - compare, () => monitor(273, 207, 737, area => chat(area.x, area.y, area.w, area.h, { mode: 'received' })));
    fade(compare, () => {
      rounded(69, 209, 1141, 46, 9, '#e2e9dc');
      text('✓  Annotated screenshot received in your chat', 91, 239, 17, C.sage, 'sans', 500);
      text('YOUR FEEDBACK', 75, 294, 12, C.muted, 'sans', 500);
      text('THE NEXT VERSION', 676, 294, 12, C.muted, 'sans', 500);
      shadow(() => screen(68, 316, 543, 339.4, { annotations: 1 }), 24, .1);
      shadow(() => screen(669, 316, 543, 339.4, { calm: true, annotations: phase(local, 2.05, 3.9), activePencil: local > 2.05 && local < 3.9 }), 24, .1);
      line(640, 332, 640, 640);
    });
    fade(phase(local, 3.85, 4.55), () => {
      const next = phase(local, 4.25, 5.4);
      ctx.save(); ctx.setLineDash([7, 6]); ctx.strokeStyle = C.sage; ctx.lineWidth = 1.5;
      ctx.strokeRect(686, 332, 509 * next, 306 * next); ctx.restore();
      const cx = 686 + 509 * next, cy = 332 + 306 * next;
      line(cx - 11, cy, cx + 11, cy, C.sage, 2); line(cx, cy - 11, cx, cy + 11, C.sage, 2);
      text('Your next screenshot starts here.', 73, 711, 28, C.ink, 'serif');
      text('CAPTURE  →  MARK  →  DONE  →  ⌘ V  →  REPEAT', 75, 756, 15, C.muted, 'sans', 500);
      stroke([[1025, 712], [1090, 708], [1126, 690], [1138, 671], [1123, 680], [1138, 671], [1138, 688]], next, C.sage, 2.5);
    });
  }
  const scenes = [confusion, intro, capture, annotate, attach, revision];
  function drawScene(i, local, alpha = 1) {
    fade(alpha, () => { ctx.fillStyle = C.paper; ctx.fillRect(0, 0, W, H); scenes[i](local); });
  }
  function syncUI() {
    const index = sceneAt(t), active = playing && inView && !document.hidden;
    if (ui.toggle) {
      const label = playing ? 'Pause film' : 'Play film';
      ui.toggle.setAttribute('aria-label', label); ui.toggle.title = label;
      ui.toggle.dataset.state = playing ? 'playing' : 'paused';
      const content = ui.toggle.querySelector('[data-film-toggle-label]');
      if (content) content.textContent = playing ? 'Pause' : 'Play';
      else if (!ui.toggle.querySelector('svg')) ui.toggle.textContent = playing ? 'Pause' : 'Play';
    }
    if (ui.stage) { ui.stage.dataset.playing = String(active); ui.stage.dataset.scene = String(index); }
    if (ui.seek) { ui.seek.value = String(t); ui.seek.setAttribute('aria-valuetext', `${t.toFixed(1)} seconds of 36`); }
    if (ui.time) ui.time.textContent = `0:${String(Math.floor(t)).padStart(2, '0')} / 0:36`;
    if (captionIndex !== index) {
      captionIndex = index;
      if (ui.caption) ui.caption.textContent = captions[index];
      ui.scenes.forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.filmScene) === index)));
    }
    window.dispatchEvent(new CustomEvent('ludwig:film-state', { detail: { time: t, playing: active, duration: DURATION } }));
  }
  function render(time = t) {
    const value = Number(time); t = clamp(Number.isFinite(value) ? value : t, 0, DURATION);
    ctx.save(); ctx.setTransform(canvas.width / W, 0, 0, canvas.height / H, 0, 0);
    ctx.clearRect(0, 0, W, H); ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
    const index = sceneAt(t), local = t - starts[index];
    drawScene(index, local);
    if (index < scenes.length - 1) {
      const blend = clamp((t - (starts[index + 1] - .42)) / .42);
      if (blend > 0) {
        ctx.save(); ctx.beginPath(); ctx.rect(W * (1 - ease(blend)), 0, W, H); ctx.clip();
        drawScene(index + 1, 0); ctx.restore();
        line(W * (1 - ease(blend)), 0, W * (1 - ease(blend)), H, '#d6cebf', 2);
      }
    }
    ctx.restore(); syncUI();
  }
  function tick(stamp) {
    frame = 0;
    if (!playing || !inView || document.hidden) { last = null; return; }
    if (last !== null) t = Math.min(DURATION, t + Math.max(0, stamp - last) / 1000);
    last = stamp;
    if (t >= DURATION) { playing = false; last = null; }
    render(); if (playing) frame = requestAnimationFrame(tick);
  }
  function schedule() {
    cancelAnimationFrame(frame); frame = 0; last = null;
    if (playing && inView && !document.hidden) frame = requestAnimationFrame(tick);
    syncUI();
  }
  function pause() { playing = false; schedule(); }
  function play() { if (t >= DURATION) t = 0; playing = true; render(); schedule(); }
  function seek(time) { pause(); render(time); }
  ui.toggle?.addEventListener('click', () => playing ? pause() : play());
  ui.replay?.addEventListener('click', () => { seek(0); play(); });
  ui.seek?.addEventListener('input', event => seek(Number(event.currentTarget.value)));
  ui.scenes.forEach(button => button.addEventListener('click', () => {
    const index = Number(button.dataset.filmScene);
    if (Number.isInteger(index) && index >= 0 && index < stills.length) seek(stills[index]);
  }));
  document.addEventListener('visibilitychange', schedule);
  if (window.LudwigMotion) window.addEventListener('ludwig:motion-preference', event => {
    if (!event.detail.allowed) { pause(); render(t === 0 ? 20.5 : t); }
  });
  else reduce.addEventListener('change', event => { if (event.matches) { pause(); render(t === 0 ? 20.5 : t); } });
  if ('IntersectionObserver' in window) {
    const rect = canvas.getBoundingClientRect();
    inView = rect.bottom > 0 && rect.top < window.innerHeight;
    new IntersectionObserver(entries => { inView = entries[0].isIntersecting; schedule(); }, { threshold: .08 }).observe(canvas);
  }
  portrait.onload = () => render(); portrait.src = '/assets/ludwig-portrait.png';
  window.LudwigCharacter?.ready?.then(() => render());
  document.fonts?.ready.then(() => render());
  window.ludwigFilm = Object.freeze({ seek, pause, play, render, get isPlaying() { return playing; } });
  render(); schedule();
})();
