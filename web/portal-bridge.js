(function () {
  'use strict';
  const id = String(window.LAST_HAND_CONFIG?.gameId || '').trim();
  let ready = false, busy = false, paused = false, handler = null;
  const emit = name => { if (handler) handler(name); };
  window.lastHandPortal = Object.freeze({
    get ready() { return Boolean(id && ready && window.sdk && typeof window.sdk.showBanner === 'function'); },
    setHandler(callback) {
      handler = typeof callback === 'function' ? callback : null;
      if (paused) emit('SDK_GAME_PAUSE');
      else if (ready) emit('SDK_READY');
    },
    showAd() {
      if (!this.ready || busy) return false;
      busy = true;
      try { window.sdk.showBanner(); return true; }
      catch (_) { busy = false; return false; }
    }
  });
  if (!id) return;
  window.SDK_OPTIONS = {
    gameId: id,
    onEvent(event) {
      switch (event.name) {
        case 'SDK_READY': ready = true; emit(event.name); break;
        case 'SDK_GAME_PAUSE': paused = true; busy = true; emit(event.name); break;
        case 'SDK_GAME_START': paused = false; busy = false; emit(event.name); break;
      }
    }
  };
  const script = document.createElement('script');
  script.id = 'gamemonetize-sdk';
  script.src = 'https://api.gamemonetize.com/sdk.js';
  script.async = true;
  script.onerror = () => { ready = false; emit('SDK_UNAVAILABLE'); };
  document.head.appendChild(script);
}());
