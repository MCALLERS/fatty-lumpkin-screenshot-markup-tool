/* A shared, time-driven performance for the original Ludwig illustration. */
(() => {
  'use strict';

  const SOURCE_WIDTH = 1448;
  const SOURCE_HEIGHT = 1086;
  const PERIOD = 8;
  const image = new Image();
  const downImage = new Image();
  const EYES = { x: 657, y: 230, width: 270, height: 145 };
  let downEyes = null;
  let loaded = false;
  let triangles = [];

  // The denser part of this continuous mesh follows the drawing hand and pencil.
  // It has at most 280 triangles; empty transparent cells are removed on load.
  const columns = [0, 180, 280, 340, 390, 440, 495, 550, 625, 710, 800, 900, 1010, 1190, 1448];
  const rows = [0, 170, 340, 500, 610, 680, 750, 820, 890, 960, 1086];
  const vertices = rows.flatMap(y => columns.map(x => ({ x, y })));
  const transformed = vertices.map(() => ({ x: 0, y: 0 }));
  const clamp = value => Math.max(0, Math.min(1, value));
  const smooth = (low, high, value) => {
    const p = clamp((value - low) / (high - low));
    return p * p * (3 - 2 * p);
  };
  const cycle = time => ((time % PERIOD) + PERIOD) % PERIOD;

  function segmentDistance(x, y, ax, ay, bx, by) {
    const dx = bx - ax, dy = by - ay;
    const p = clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy));
    return Math.hypot(x - ax - dx * p, y - ay - dy * p);
  }

  // An open oval: the nib traces the same line that appears on the paper.
  // These are original-image coordinates, so the movement scales with the art.
  function inkPoint(progress) {
    const angle = Math.PI + progress * Math.PI * 1.85;
    return {
      x: 572 + Math.cos(angle) * 29,
      y: 913 + Math.sin(angle) * 13 + Math.sin(progress * Math.PI * 3) * 1.4
    };
  }

  function pose(time) {
    const t = cycle(Number.isFinite(time) ? time : 0);
    const progress = smooth(.85, 4.75, t);
    const returnHome = smooth(5.45, 7.7, t);
    const mark = inkPoint(progress);
    const penDown = smooth(.2, .85, t) * (1 - smooth(4.75, 5.25, t));
    const lift = smooth(4.75, 5.25, t) * (1 - returnHome);
    const intent = smooth(.1, 1.1, t) * (1 - smooth(4.7, 6.2, t));
    // He is absorbed in the page on arrival, then briefly acknowledges the
    // viewer between strokes. The lowered gaze is also the still-frame pose.
    const glanceUp = smooth(5.15, 5.55, t) * (1 - smooth(6.05, 6.5, t));
    const gazeDown = 1 - glanceUp;
    const lookingUp = t >= 5.35 && t < 6.275;
    return {
      t, progress, gazeDown, lookingUp,
      inkAlpha: 1 - smooth(6.35, 7.7, t),
      handX: (mark.x - 543) * (1 - returnHome),
      handY: (mark.y - 913) * (1 - returnHome) - 11 * lift,
      wristAngle: (Math.sin(progress * Math.PI * 2) * .018 * penDown) - lift * .014,
      headAngle: -.033 * gazeDown + Math.sin(t / PERIOD * Math.PI * 2) * .025,
      headDrop: 9 * gazeDown + 2 * intent,
      breath: Math.sin(t / PERIOD * Math.PI * 2) * 1.6
    };
  }

  // All regions contribute to one vertex field. There are no duplicated limbs,
  // detached image patches or holes beneath a rotating head/hand cutout.
  function deform(x, y, p) {
    const headX = smooth(540, 640, x) * (1 - smooth(1030, 1155, x));
    const headY = 1 - smooth(505, 695, y);
    const headWeight = headX * headY;
    const hx = x - 790, hy = y - 600;
    const hc = Math.cos(p.headAngle), hs = Math.sin(p.headAngle);
    let dx = (hx * hc - hy * hs - hx) * headWeight;
    let dy = (hx * hs + hy * hc - hy + p.headDrop) * headWeight;

    const handDistance = Math.hypot((x - 444) / 144, (y - 823) / 132);
    const hand = 1 - smooth(.76, 1.68, handDistance);
    const pencil = 1 - smooth(68, 152, segmentDistance(x, y, 362, 636, 543, 913));
    // The notebook settles back to its original shape below the wrist.
    const handWeight = Math.max(hand, pencil) * (1 - smooth(935, 1010, y));
    const wx = x - 350, wy = y - 850;
    const wc = Math.cos(p.wristAngle), ws = Math.sin(p.wristAngle);
    dx += (p.handX + wx * wc - wy * ws - wx) * handWeight;
    dy += (p.handY + wx * ws + wy * wc - wy) * handWeight;

    const body = Math.exp(-Math.pow((x - 739) / 490, 2)) * smooth(340, 610, y) * (1 - smooth(870, 1010, y));
    dy += p.breath * body;
    return { x: x + dx, y: y + dy };
  }

  function nibAtProgress(progress) {
    // Match the actual piecewise-affine mesh at the nib, rather than assuming
    // the entire hand has undergone a rigid translation. This keeps ink contact
    // registered even where a mesh triangle blends into the resting notebook.
    const inverseSmooth = .5 - Math.sin(Math.asin(1 - 2 * clamp(progress)) / 3);
    const p = pose(.85 + 3.9 * inverseSmooth);
    const a = deform(495, 890, p), b = deform(550, 890, p), d = deform(550, 960, p);
    const fx = (543 - 495) / 55, fy = (913 - 890) / 70;
    return {
      x: a.x * (1 - fx) + b.x * (fx - fy) + d.x * fy,
      y: a.y * (1 - fx) + b.y * (fx - fy) + d.y * fy
    };
  }

  function makeTriangle(a, b, c) {
    const p = vertices[a], q = vertices[b], r = vertices[c];
    const determinant = (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    return {
      a, b, c,
      p, q, r,
      inverse: 1 / determinant,
      sx: Math.min(p.x, q.x, r.x), sy: Math.min(p.y, q.y, r.y),
      sw: Math.max(p.x, q.x, r.x) - Math.min(p.x, q.x, r.x),
      sh: Math.max(p.y, q.y, r.y) - Math.min(p.y, q.y, r.y)
    };
  }

  function prepareMesh() {
    let alpha = null;
    try {
      const probe = document.createElement('canvas');
      probe.width = SOURCE_WIDTH; probe.height = SOURCE_HEIGHT;
      const probeContext = probe.getContext('2d', { willReadFrequently: true });
      probeContext.drawImage(image, 0, 0, SOURCE_WIDTH, SOURCE_HEIGHT);
      alpha = probeContext.getImageData(0, 0, SOURCE_WIDTH, SOURCE_HEIGHT).data;
    } catch (_) {
      // A restrictive embedding can forbid readback; full mesh is still valid.
    }
    const visible = (left, top, right, bottom) => {
      if (!alpha) return true;
      for (let y = top; y < bottom; y += 4) {
        for (let x = left; x < right; x += 4) {
          if (alpha[(y * SOURCE_WIDTH + x) * 4 + 3] > 8) return true;
        }
      }
      return false;
    };
    for (let y = 0; y < rows.length - 1; y++) {
      for (let x = 0; x < columns.length - 1; x++) {
        if (!visible(columns[x], rows[y], columns[x + 1], rows[y + 1])) continue;
        const a = y * columns.length + x;
        const b = a + 1, c = a + columns.length, d = c + 1;
        triangles.push(makeTriangle(a, b, d), makeTriangle(a, d, c));
      }
    }
  }

  function prepareEyes() {
    if (!downImage.naturalWidth) return;
    // The generated cel is only sampled around the eyes. Its hair, body and
    // paper are never used, so the original silhouette and texture stay fixed.
    const patch = document.createElement('canvas');
    patch.width = EYES.width; patch.height = EYES.height;
    const patchContext = patch.getContext('2d');
    const mask = document.createElement('canvas');
    mask.width = EYES.width; mask.height = EYES.height;
    const maskContext = mask.getContext('2d');
    if (!patchContext || !maskContext) return;
    patchContext.drawImage(downImage, 0, 0, downImage.naturalWidth, downImage.naturalHeight,
      7 - EYES.x, -2 - EYES.y, SOURCE_WIDTH, SOURCE_HEIGHT);
    const featherEye = (x, y, rx, ry, angle) => {
      maskContext.save();
      maskContext.translate(x - EYES.x, y - EYES.y);
      maskContext.rotate(angle); maskContext.scale(rx, ry);
      const feather = maskContext.createRadialGradient(0, 0, .58, 0, 0, 1);
      feather.addColorStop(0, '#fff'); feather.addColorStop(1, '#fff0');
      maskContext.fillStyle = feather; maskContext.fillRect(-1, -1, 2, 2);
      maskContext.restore();
    };
    featherEye(731, 292, 67, 54, .26);
    featherEye(846, 319, 66, 49, .21);
    patchContext.globalCompositeOperation = 'destination-in';
    patchContext.drawImage(mask, 0, 0);
    downEyes = patch;
  }

  function drawTriangle(ctx, triangle, overlap, eyePose) {
    const { p, q, r, inverse } = triangle;
    const a = transformed[triangle.a], b = transformed[triangle.b], c = transformed[triangle.c];
    const m11 = ((b.x - a.x) * (r.y - p.y) - (c.x - a.x) * (q.y - p.y)) * inverse;
    const m12 = ((b.y - a.y) * (r.y - p.y) - (c.y - a.y) * (q.y - p.y)) * inverse;
    const m21 = ((c.x - a.x) * (q.x - p.x) - (b.x - a.x) * (r.x - p.x)) * inverse;
    const m22 = ((c.y - a.y) * (q.x - p.x) - (b.y - a.y) * (r.x - p.x)) * inverse;
    const tx = a.x - m11 * p.x - m21 * p.y;
    const ty = a.y - m12 * p.x - m22 * p.y;
    const centerX = (a.x + b.x + c.x) / 3, centerY = (a.y + b.y + c.y) / 3;

    ctx.save();
    ctx.beginPath();
    [a, b, c].forEach((point, index) => {
      const dx = point.x - centerX, dy = point.y - centerY;
      const extra = overlap / Math.max(1, Math.hypot(dx, dy));
      const px = point.x + dx * extra, py = point.y + dy * extra;
      if (index === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    });
    ctx.closePath(); ctx.clip();
    ctx.transform(m11, m12, m21, m22, tx, ty);
    // Include a source-pixel margin under the expanded clip to hide hairline seams.
    const sx = Math.max(0, triangle.sx - 2), sy = Math.max(0, triangle.sy - 2);
    const sw = Math.min(SOURCE_WIDTH - sx, triangle.sw + 4);
    const sh = Math.min(SOURCE_HEIGHT - sy, triangle.sh + 4);
    ctx.drawImage(image, sx, sy, sw, sh, sx, sy, sw, sh);
    if (eyePose && sx < EYES.x + EYES.width && sx + sw > EYES.x && sy < EYES.y + EYES.height && sy + sh > EYES.y) {
      ctx.drawImage(eyePose, EYES.x, EYES.y);
    }
    ctx.restore();
  }

  function drawNotebookInk(ctx, p) {
    if (p.progress <= 0 || p.inkAlpha <= 0) return;
    ctx.save();
    ctx.globalAlpha *= p.inkAlpha * .93;
    ctx.strokeStyle = '#b83b2a'; ctx.lineWidth = 2.25;
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    ctx.beginPath();
    const count = Math.max(2, Math.ceil(52 * p.progress));
    for (let i = 0; i <= count; i++) {
      const point = nibAtProgress(p.progress * i / count);
      if (i === 0) ctx.moveTo(point.x, point.y); else ctx.lineTo(point.x, point.y);
    }
    ctx.stroke(); ctx.restore();
  }

  /** Render at an explicit time in seconds. Returns false until the asset loads. */
  function draw(ctx, options = {}) {
    if (!loaded || !ctx) return false;
    const { x = 0, y = 0, width = SOURCE_WIDTH, time = 0, drawInk = true } = options;
    if (!Number.isFinite(width) || width <= 0) return false;
    const p = pose(time);
    for (let i = 0; i < vertices.length; i++) {
      const source = vertices[i], point = deform(source.x, source.y, p);
      transformed[i].x = point.x; transformed[i].y = point.y;
    }
    const scale = width / SOURCE_WIDTH;
    ctx.save(); ctx.translate(x, y); ctx.scale(scale, scale);
    // Stay within the declared 4:3 box; edge hair details are never stretched out.
    ctx.beginPath(); ctx.rect(0, 0, SOURCE_WIDTH, SOURCE_HEIGHT); ctx.clip();
    const overlap = Math.min(1.5, .32 / scale);
    // A clean cel change preserves the eye drawing. Crossfading the two gaze
    // positions would produce doubled pupils; the surrounding head moves smoothly.
    const eyePose = p.lookingUp ? null : downEyes;
    for (const triangle of triangles) drawTriangle(ctx, triangle, overlap, eyePose);
    if (drawInk) drawNotebookInk(ctx, p);
    ctx.restore();
    return true;
  }

  const loadImage = (target, path) => new Promise(resolve => {
    target.onload = () => resolve(true);
    target.onerror = () => resolve(false);
    target.src = path;
  });
  const ready = Promise.all([
    loadImage(image, '/assets/ludwig-portrait.png'),
    loadImage(downImage, '/assets/ludwig-looking-down.png')
  ]).then(([hasPortrait]) => {
    if (!hasPortrait) return false;
    prepareMesh(); prepareEyes(); loaded = true; return true;
  });
  window.LudwigCharacter = Object.freeze({ ready, draw });
})();
