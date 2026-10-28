/* An explicit site choice takes precedence over the device motion preference. */
(() => {
  'use strict';
  const key = 'ludwig-motion-preference';
  const device = window.matchMedia('(prefers-reduced-motion: reduce)');
  let choice = null;
  try {
    const saved = window.localStorage.getItem(key);
    if (saved === 'play' || saved === 'pause') choice = saved;
  } catch (_) { /* The choice still works for this page if storage is unavailable. */ }
  const allowed = () => choice === 'play' || (choice === null && !device.matches);
  function apply(reason) {
    document.documentElement.classList.toggle('motion-override', choice === 'play');
    document.documentElement.classList.toggle('motion-paused', !allowed());
    window.dispatchEvent(new CustomEvent('ludwig:motion-preference', {
      detail: { choice, allowed: allowed(), reason }
    }));
  }
  function set(value) {
    if (value !== 'play' && value !== 'pause' && value !== null) return;
    choice = value;
    try {
      if (choice === null) window.localStorage.removeItem(key);
      else window.localStorage.setItem(key, choice);
    } catch (_) {}
    apply(value === null ? 'reset' : 'choice');
  }
  device.addEventListener('change', () => apply('device'));
  window.LudwigMotion = Object.freeze({
    set, get choice() { return choice; }, get allowed() { return allowed(); }
  });
  apply('initial');
})();
