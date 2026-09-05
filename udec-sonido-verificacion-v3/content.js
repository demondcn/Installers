(() => {
  'use strict';

  const PREFIX = '__udec_asistencia_sonido__';
  const ARMED_KEY = `${PREFIX}armed_until`;
  const ARMED_MS = 20000;
  const SUCCESS_WORDS = ['DOCUMENTO', 'ROL', 'MODALIDAD'];
  const SUCCESS_SOUND = chrome.runtime.getURL('sounds/success.mp3');

  let armedUntil = Number(sessionStorage.getItem(ARMED_KEY) || 0);
  let alreadyPlayedForThisArm = false;
  let observerTimer = null;
  let audioCtx = null;
  let decodedSuccessBuffer = null;

  const normalize = (value) =>
    String(value || '')
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/\s+/g, ' ')
      .trim()
      .toUpperCase();

  function armVerification() {
    armedUntil = Date.now() + ARMED_MS;
    alreadyPlayedForThisArm = false;
    try {
      sessionStorage.setItem(ARMED_KEY, String(armedUntil));
    } catch (_) {}

    // Desbloquea WebAudio con la interacción del usuario y precarga el audio.
    try {
      if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }
      if (audioCtx.state === 'suspended') {
        audioCtx.resume().catch(() => {});
      }
      preloadSuccessSound().catch(() => {});
    } catch (_) {}

    scheduleCheck(100);
  }

  function isArmed() {
    if (!armedUntil) {
      armedUntil = Number(sessionStorage.getItem(ARMED_KEY) || 0);
    }
    return Date.now() <= armedUntil;
  }

  function pageLooksSuccessful() {
    const text = normalize(document.body?.innerText || '');
    if (!text) return false;

    const hasProfileFields = SUCCESS_WORDS.every((word) => text.includes(word));
    if (!hasProfileFields) return false;

    const hasInputPrompt = text.includes('DIGITE DOCUMENTO O CODIGO');
    const hasPersonData =
      /DOCUMENTO\s+(CC|CE|TI|PA|NIT|PEP)?\s*[A-Z0-9.-]{4,}/.test(text) ||
      /ROL\s+[A-ZÁÉÍÓÚÑ]/i.test(document.body?.innerText || '');

    return hasPersonData || !hasInputPrompt;
  }

  async function preloadSuccessSound() {
    if (decodedSuccessBuffer) return decodedSuccessBuffer;
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    const response = await fetch(SUCCESS_SOUND);
    if (!response.ok) throw new Error(`No se pudo cargar el audio (${response.status})`);
    const bytes = await response.arrayBuffer();
    decodedSuccessBuffer = await audioCtx.decodeAudioData(bytes.slice(0));
    return decodedSuccessBuffer;
  }

  async function playPackagedAudio() {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      await audioCtx.resume();
    }
    const buffer = await preloadSuccessSound();
    const source = audioCtx.createBufferSource();
    const gain = audioCtx.createGain();
    gain.gain.value = 0.9;
    source.buffer = buffer;
    source.connect(gain);
    gain.connect(audioCtx.destination);
    source.start(0);
  }

  async function playFallbackDing() {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      await audioCtx.resume();
    }

    const now = audioCtx.currentTime;
    const master = audioCtx.createGain();
    master.gain.setValueAtTime(0.0001, now);
    master.gain.exponentialRampToValueAtTime(0.22, now + 0.012);
    master.gain.exponentialRampToValueAtTime(0.0001, now + 0.42);
    master.connect(audioCtx.destination);

    const notes = [
      { frequency: 880.0, start: 0.00, duration: 0.16 },
      { frequency: 1318.51, start: 0.13, duration: 0.24 }
    ];

    for (const note of notes) {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(note.frequency, now + note.start);
      gain.gain.setValueAtTime(0.0001, now + note.start);
      gain.gain.exponentialRampToValueAtTime(0.9, now + note.start + 0.015);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + note.start + note.duration);
      osc.connect(gain);
      gain.connect(master);
      osc.start(now + note.start);
      osc.stop(now + note.start + note.duration + 0.02);
    }
  }

  async function playSuccessSound() {
    if (alreadyPlayedForThisArm) return;
    alreadyPlayedForThisArm = true;

    try {
      await playPackagedAudio();
    } catch (err) {
      console.debug('[UdeC sonido] Falló el audio, usando ding de respaldo:', err);
      try {
        await playFallbackDing();
      } catch (fallbackErr) {
        console.debug('[UdeC sonido] No fue posible reproducir sonido:', fallbackErr);
      }
    }

    armedUntil = 0;
    try {
      sessionStorage.removeItem(ARMED_KEY);
    } catch (_) {}
  }

  function checkForSuccess() {
    if (!isArmed() || alreadyPlayedForThisArm) return;
    if (pageLooksSuccessful()) {
      playSuccessSound();
    }
  }

  function scheduleCheck(delay = 0) {
    clearTimeout(observerTimer);
    observerTimer = setTimeout(checkForSuccess, delay);
  }

  document.addEventListener(
    'click',
    (event) => {
      const target = event.target?.closest?.('button, input[type="submit"], input[type="button"], a');
      if (!target) return;
      const label = normalize(target.innerText || target.value || target.textContent);
      if (label.includes('INGRESAR')) {
        armVerification();
      }
    },
    true
  );

  document.addEventListener(
    'keydown',
    (event) => {
      if (event.key !== 'Enter') return;
      const active = document.activeElement;
      const isTextInput = active && ['INPUT', 'TEXTAREA'].includes(active.tagName);
      const pageText = normalize(document.body?.innerText || '');
      if (isTextInput && pageText.includes('DIGITE DOCUMENTO O CODIGO')) {
        armVerification();
      }
    },
    true
  );

  const observer = new MutationObserver(() => scheduleCheck(80));
  if (document.documentElement) {
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: false
    });
  }

  if (isArmed()) {
    // Tras una recarga, intenta cargar el archivo y detectar la ficha.
    preloadSuccessSound().catch(() => {});
    scheduleCheck(250);
    setTimeout(checkForSuccess, 700);
    setTimeout(checkForSuccess, 1600);
  }
})();
