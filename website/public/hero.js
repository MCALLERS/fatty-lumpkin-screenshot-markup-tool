/* Ludwig keeps drawing while visible; a full gesture repeats every eight seconds. */
(() => {
  'use strict';
  const canvas = document.getElementById('hero-character');
  const button = document.getElementById('hero-animate');
  const stage = document.querySelector('.hero-art');
  if (!canvas || !button || !stage || !window.LudwigCharacter) return;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const motionAllowed = () => window.LudwigMotion?.allowed ?? !reduced.matches;
  const DURATION = 8;
  let time = 0, playing = false, ready = false, frame = 0, previous = null, lastPaint = -Infinity;
  let visible = false, introduced = false;
  button.disabled = true;
  function paint() {
    if (!ready) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    window.LudwigCharacter.draw(ctx, { x: 0, y: 0, width: canvas.width, time, drawInk: true });
  }
  function size() {
    const width = Math.max(360, Math.min(1448, Math.round(canvas.getBoundingClientRect().width * Math.min(devicePixelRatio || 1, 1.5))));
    if (canvas.width !== width) { canvas.width = width; canvas.height = Math.round(width * .75); }
    paint();
  }
  function label() {
    button.textContent = playing ? 'Pause Ludwig Ⅱ' : introduced ? 'Resume Ludwig ↗' : 'Animate Ludwig ↗';
    button.setAttribute('aria-pressed', String(playing));
    stage.classList.toggle('hero-moving', playing);
  }
  function tick(stamp) {
    frame = 0;
    if (!playing || !visible || document.hidden) { previous = null; return; }
    if (previous !== null) time = (time + Math.max(0, stamp - previous) / 1000) % DURATION;
    previous = stamp;
    if (stamp - lastPaint >= 1000 / 30) { paint(); lastPaint = stamp; }
    frame = requestAnimationFrame(tick);
  }
  function schedule() {
    cancelAnimationFrame(frame); frame = 0; previous = null;
    if (ready && playing && visible && !document.hidden) frame = requestAnimationFrame(tick);
  }
  function pause() { playing = false; label(); schedule(); }
  function play() {
    if (!ready) return;
    introduced = true; playing = true; label(); schedule();
  }
  function replay() { time = 0; paint(); play(); }
  button.addEventListener('click', () => playing ? pause() : play());
  if ('IntersectionObserver' in window) new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting;
    stage.classList.toggle('is-offscreen', !visible);
    startOnArrival(); schedule();
  }, { threshold: .08 }).observe(stage);
  else visible = true;
  function startOnArrival() {
    if (!introduced && motionAllowed() && visible && ready && !document.documentElement.classList.contains('motion-paused')) play();
  }
  document.addEventListener('visibilitychange', schedule);
  if (window.LudwigMotion) window.addEventListener('ludwig:motion-preference', event => {
    if (!event.detail.allowed && playing) pause();
  });
  else reduced.addEventListener('change', event => { if (event.matches) pause(); });
  window.LudwigCharacter.ready.then(loaded => {
    if (!loaded) throw new Error('Character asset unavailable');
    ready = true; size(); stage.classList.add('character-ready'); button.disabled = false; label(); startOnArrival();
    if ('ResizeObserver' in window) new ResizeObserver(size).observe(canvas);
  }).catch(() => { button.textContent = 'Illustrated Ludwig'; button.disabled = true; });
  window.ludwigHero = Object.freeze({ play, replay, pause, get isPlaying() { return playing; } });
})();
