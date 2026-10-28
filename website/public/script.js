(() => {
  'use strict';
  const demo = document.querySelector('#workflow-demo');
  if (!demo) return;
  const steps = [...demo.querySelectorAll('[data-step]')];
  const pause = document.querySelector('#motion-control');
  const replay = document.querySelector('#replay-control');
  const status = document.querySelector('#demo-status');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const duration = 5800;
  const descriptions = {
    1: 'Step 1: Capture with Shift, Command, 4 on your Mac.',
    2: 'Step 2: Circle, sketch, or write on your iPad.',
    3: 'Step 3: Tap Done, wait for the Mac clipboard confirmation, and paste into your AI tool.'
  };
  let current = 1;
  let playing = !reducedMotion.matches;
  let timer;
  let remaining = duration;
  let startedAt = 0;
  let inView = true;

  const clearTimer = () => { window.clearTimeout(timer); timer = undefined; };
  function schedule() {
    clearTimer();
    if (!playing || !inView || document.hidden) return;
    startedAt = performance.now();
    timer = window.setTimeout(() => setStep(current % 3 + 1), remaining);
  }
  function updatePlayback() {
    const stopped = !playing || !inView || document.hidden;
    demo.classList.toggle('paused', stopped);
    pause.setAttribute('aria-label', playing ? 'Pause animation' : 'Play animation');
    pause.title = playing ? 'Pause animation' : 'Play animation';
    if (stopped) {
      if (timer !== undefined) remaining = Math.max(0, remaining - (performance.now() - startedAt));
      clearTimer();
    } else schedule();
  }
  function setStep(number, announce = false) {
    current = number;
    demo.classList.remove('stage-1', 'stage-2', 'stage-3');
    // Restart CSS progress when replaying the currently selected stage.
    void demo.offsetWidth;
    demo.classList.add(`stage-${number}`);
    steps.forEach(button => {
      const active = Number(button.dataset.step) === number;
      button.classList.toggle('active', active);
      button.setAttribute('aria-pressed', String(active));
      if (active) { button.querySelector('i').style.animation = 'none'; }
    });
    void demo.offsetWidth;
    steps.forEach(button => { button.querySelector('i').style.removeProperty('animation'); });
    remaining = duration;
    if (announce) status.textContent = descriptions[number];
    schedule();
  }
  steps.forEach(button => button.addEventListener('click', () => {
    playing = false;
    demo.classList.add('is-manual');
    setStep(Number(button.dataset.step), true);
    updatePlayback();
  }));
  pause.addEventListener('click', () => {
    playing = !playing;
    if (playing) demo.classList.remove('is-manual');
    updatePlayback();
  });
  replay.addEventListener('click', () => {
    playing = !reducedMotion.matches;
    demo.classList.toggle('is-manual', !playing);
    setStep(1, true);
    updatePlayback();
  });
  document.addEventListener('visibilitychange', updatePlayback);
  reducedMotion.addEventListener('change', event => {
    playing = !event.matches;
    demo.classList.toggle('is-manual', event.matches);
    if (event.matches) setStep(2);
    updatePlayback();
  });
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(entries => {
      inView = entries[0].isIntersecting;
      updatePlayback();
    }, { threshold: 0.1 }).observe(demo);
  }
  if (reducedMotion.matches) {
    demo.classList.add('is-manual');
    setStep(2);
  }
  updatePlayback();
})();
