(() => {
  'use strict';
  const example = document.getElementById('feedback-example');
  const tabs = [...document.querySelectorAll('.layer-tabs [role="tab"]')];
  const layers = {
    example: ['01', 'First, a shared reference.', 'Layout, color, spacing, proportion. A picture puts the example in front of your AI agent, without a paragraph describing where everything is.'],
    grade: ['02', 'Then, your reaction.', 'B+ says this is promising, with room to improve. A grade gives the example a direction. The reasons make that judgment useful.'],
    reason: ['03', 'Point to what matters.', 'Move this card. Make that headline bigger. Calm the colors. Arrows and a few words put each change exactly where you mean it.'],
    full: ['04', 'Now your taste has context.', 'The picture gives your agent a reference. The grade gives it your reaction. The notes explain what to preserve, what to change, and why.']
  };
  function selectLayer(tab) {
    const key = tab.dataset.layer;
    if (!example || !layers[key]) return;
    example.dataset.layer = key;
    const descriptions = {
      example: 'A fictional Fieldnotes design screenshot with a headline and three cards: yellow, orange, then blue.',
      grade: 'The fictional design screenshot is graded B plus.',
      reason: 'Handwritten notes request a bigger, nicer headline font, move the blue third card before the orange second card, and suggest calmer colors.',
      full: 'A fictional design screenshot graded B plus. Handwritten notes ask for a bigger, nicer headline font, move the blue third card before the orange second card, and suggest calmer colors.'
    };
    example.querySelector('.feedback-drawing')?.setAttribute('aria-label', descriptions[key]);
    example.querySelector('.annotation-grade')?.setAttribute('aria-hidden', String(key === 'example' || key === 'reason'));
    example.querySelectorAll('.annotation-reason').forEach(item => item.setAttribute('aria-hidden', String(key === 'example' || key === 'grade')));
    tabs.forEach(item => { item.setAttribute('aria-selected', String(item === tab)); item.tabIndex = item === tab ? 0 : -1; });
    document.getElementById('layer-panel').setAttribute('aria-labelledby', tab.id);
    ['layer-index', 'layer-title', 'layer-description'].forEach((id, i) => document.getElementById(id).textContent = layers[key][i]);
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectLayer(tab));
    tab.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next === undefined) return;
      event.preventDefault(); selectLayer(tabs[next]); tabs[next].focus();
    });
  });
  const hero = document.querySelector('.hero-art');
  if (hero && 'IntersectionObserver' in window) new IntersectionObserver(entries => {
    hero.classList.toggle('is-offscreen', !entries[0].isIntersecting);
  }, { threshold: 0 }).observe(hero);
  const motion = document.getElementById('global-motion');
  const resetMotion = document.getElementById('motion-device-default');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const preference = window.LudwigMotion;
  const players = () => [window.ludwigFilm, window.ludwigHero].filter(Boolean);
  // Null means the page arrived paused. Resume then starts the available players.
  let resumePlayers = null;
  function setPagePaused(paused) {
    document.documentElement.classList.toggle('motion-paused', paused);
    motion?.setAttribute('aria-pressed', String(paused));
    if (motion) motion.textContent = paused ? 'Resume page motion' : 'Pause page motion';
  }
  motion?.addEventListener('click', () => {
    const paused = !document.documentElement.classList.contains('motion-paused');
    if (paused) {
      resumePlayers = players().filter(player => player.isPlaying);
      players().forEach(player => player.pause());
      preference?.set('pause');
    } else {
      const previous = resumePlayers ?? players(); resumePlayers = [];
      preference?.set('play');
      previous.forEach(player => player.play());
    }
    setPagePaused(paused);
  });
  function syncPreference() {
    if (!preference) return;
    setPagePaused(!preference.allowed);
    if (resetMotion) resetMotion.hidden = preference.choice === null;
  }
  window.addEventListener('ludwig:motion-preference', event => {
    if (event.detail.reason === 'reset') resumePlayers = null;
    syncPreference();
  });
  resetMotion?.addEventListener('click', () => {
    // Keep keyboard focus on a visible control when the reset button disappears.
    motion?.focus(); preference?.set(null);
  });
  if (!preference) reducedMotion.addEventListener('change', event => { if (event.matches) resumePlayers = []; });
  syncPreference();
  [['film-toggle', 'ludwigFilm'], ['film-replay', 'ludwigFilm'], ['hero-animate', 'ludwigHero']].forEach(([id, key]) => {
    document.getElementById(id)?.addEventListener('click', () => {
      // These handlers run after the player's handler. An explicit Play overrides
      // the page pause for that player; the other player stays where it was.
      if (window[key]?.isPlaying) {
        resumePlayers = []; preference?.set('play'); setPagePaused(false);
      }
    });
  });
  const keepFilmPaused = () => { resumePlayers = (resumePlayers ?? players()).filter(player => player !== window.ludwigFilm); };
  document.getElementById('film-seek')?.addEventListener('input', keepFilmPaused);
  document.querySelectorAll('[data-film-scene]').forEach(button => button.addEventListener('click', keepFilmPaused));
  document.addEventListener('visibilitychange', () => document.documentElement.classList.toggle('page-hidden', document.hidden));
})();
