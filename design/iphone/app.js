// Written by AI on 2026.11.18 by model claude fable 5.2. The iPhone design prototype: one screen that
// says when the rain changes, draws the two hours, and shows the same two hours on the map.
// The forecast, its words and its line come from site/rain.js (the app's rules in JavaScript).
import { forecastFor, forecastAt, copy, clock, words } from './rain.js';
import { mapGeometry, loadCells, painter } from './radar.js';
import { drawGraph, drawRing, COLOURS } from './draw.js';

const MINUTE = 60_000, STEP = 5 * MINUTE;
// The map opens 60 km across when rain is due here and 180 km when it is not: rain moves at up to
// about 60 km/h, so 180 km across and 230 km tall holds all the rain that could arrive within two hours.
const CLOSE = 60, WIDE = 180;
const query = new URLSearchParams(location.search);
const language = query.get('lang') === 'nl' ? 'nl' : 'en';
const variant = query.get('v') ?? 'main';
const theme = query.get('theme') === 'light' ? 'light' : 'dark';
const saved = query.get('run') === 'saved';
const BASE = saved ? '/saved' : '';
const playMode = query.get('play') ?? 'once';   // once | loop | rest
const $ = id => document.getElementById(id);

// Live towns, and the three places the App Store pictures use in the saved run.
const TOWNS = saved
  ? [['Siegerswoude', 53.10, 6.25], ['Feanwâlden', 53.25, 6.00], ['Zundert', 51.40, 4.60], ['Groningen', 53.2194, 6.5665], ['Leeuwarden', 53.2012, 5.7999]]
  : [['Amsterdam', 52.3728, 4.8936], ['Rotterdam', 51.9225, 4.4792], ['Den Haag', 52.0705, 4.3007], ['Utrecht', 52.0907, 5.1214],
     ['Eindhoven', 51.4416, 5.4697], ['Groningen', 53.2194, 6.5665], ['Maastricht', 50.8514, 5.6910], ['Zwolle', 52.5168, 6.0830],
     ['Arnhem', 51.9851, 5.8987], ['Leeuwarden', 53.2012, 5.7999], ['Middelburg', 51.4988, 3.6110], ['Den Helder', 52.9563, 4.7608],
     ['Enschede', 52.2215, 6.8937], ['Breda', 51.5719, 4.7683], ['Antwerpen', 51.2194, 4.4025], ['Brussel', 50.8503, 4.3517], ['Keulen', 50.9375, 6.9603]];

const given = query.get('at')?.split(',');
if (given) TOWNS.unshift([given[2] ?? 'My Location', Number(given[0]), Number(given[1])]);
const apple = query.get('source') === 'apple';   // stands in for Apple Weather abroad: one hour, no radar

const TEXT = {
  en: { now: 'Now', inMinutes: m => `in ${m} min`, source: 'Source: KNMI', couldNot: 'Forecast Unavailable', radar: 'Radar' },
  nl: { now: 'Nu', inMinutes: m => `over ${m} min`, source: 'Bron: KNMI', couldNot: 'Geen verwachting', radar: 'Radar' },
}[language];

const phone = $('phone');
phone.classList.add(theme, `v-${variant}`);
if (query.has('bare')) document.body.style.background = 'transparent';

let state = null;        // { forecast, said, latest, town, timeline }
let radar = null;        // { paint, frames: Map, geometry, viewKm }
let viewKm = null;
let moment = 0, playing = false, held = false, lastTick = 0, pauseUntil = 0, ended = false;

// ---- The map ----

async function loadMap() {
  const { town, latest, forecast } = state, box = $('map').getBoundingClientRect();
  const w = Math.round(box.width), h = Math.round(box.height);
  if (!w || !h) return;
  const km = viewKm, mine = radar = { km };
  const q = `lat=${town[1]}&lon=${town[2]}&km=${km}&w=${w}&h=${h}&mode=${theme}`;
  const facts = await (await fetch(`/map?${q}&facts=1`)).json();
  if (radar !== mine) return;
  $('mapPicture').src = `/map?${q}`;
  const geometry = mapGeometry({ latitude: town[1], longitude: town[2] }, facts.ptPerDegLon, w, h);
  const cells = await loadCells(BASE, latest, geometry);
  if (radar !== mine) return;
  const paint = painter(cells, geometry, km, theme, 0.75, query.has('cells'));
  const canvas = $('rain');
  canvas.width = paint.width; canvas.height = paint.height;
  const at = geometry.point({ latitude: town[1], longitude: town[2] });
  $('dot').style.left = `${at.x}px`; $('dot').style.top = `${at.y}px`;
  Object.assign(mine, { paint, images: new Map(), cells, shown: -1 });
  showMoment();
}

function frameAt(time) {
  const { latest } = state, first = Date.parse(latest.run) + latest.first_frame_minutes * MINUTE;
  return Math.max(0, Math.min(latest.frames - 1, Math.floor((time - first) / (latest.step_minutes * MINUTE))));
}

function showMoment() {
  if (!state?.forecast) return;
  const { forecast } = state, marker = document.getElementById('marker');
  const position = forecast.position(moment);
  if (marker) {
    marker.setAttribute('transform', `translate(${(position * state.graphWidth).toFixed(1)} 0)`);
    // Resting on now with nothing moving, the hairline would read as the graph's own axis.
    marker.style.display = playing || held || moment > forecast.start ? '' : 'none';
  }
  const minutes = Math.round((moment - forecast.start) / MINUTE / 5) * 5;
  $('moment').textContent = minutes <= 0 ? TEXT.now : TEXT.inMinutes(minutes);
  if (radar?.paint) {
    const frame = frameAt(moment);
    if (frame !== radar.shown) {
      if (!radar.images.has(frame)) radar.images.set(frame, radar.paint.paint(frame));
      $('rain').getContext('2d').putImageData(radar.images.get(frame), 0, 0);
      radar.shown = frame;
    }
  }
}

// ---- Playing and dragging ----

const ICON = { play: '<path d="M6.5 3.8v12.4c0 .7.8 1.1 1.4.7l9.2-6.2c.5-.3.5-1.1 0-1.4L7.9 3.1c-.6-.4-1.4 0-1.4.7Z" fill="currentColor"/>', pause: '<rect x="4.5" y="3.5" width="4" height="13" rx="1.2" fill="currentColor"/><rect x="11.5" y="3.5" width="4" height="13" rx="1.2" fill="currentColor"/>' };
function setPlaying(on) { playing = on; $('playIcon').innerHTML = on ? ICON.pause : ICON.play; $('play').setAttribute('aria-label', on ? 'Pause' : 'Play'); lastTick = 0; }

function tick(time) {
  requestAnimationFrame(tick);
  if (!state?.forecast || !playing || held) { lastTick = 0; return; }
  if (time < pauseUntil) { lastTick = 0; return; }
  const { forecast } = state, span = forecast.forecastEnd - forecast.start;
  if (lastTick) moment += (time - lastTick) / 7000 * span;
  lastTick = time;
  if (moment >= forecast.forecastEnd) {
    if (!ended) { ended = true; pauseUntil = time + 900; showMomentAt(forecast.forecastEnd); return; }
    // Once through, the map goes back to now and waits: at a glance it must show the present.
    ended = false; moment = forecast.start;
    if (playMode === 'loop') pauseUntil = time + 1600; else setPlaying(false);
  }
  showMoment();
}
function showMomentAt(time) { const keep = moment; moment = time; showMoment(); moment = keep; }

function drag(event) {
  if (!state?.forecast) return;
  const box = $('graph').querySelector('svg').getBoundingClientRect(), { forecast } = state;
  const position = Math.max(0, Math.min(1, (event.clientX - box.left) / box.width));
  moment = Math.min(forecast.forecastEnd, forecast.start + Math.round(position * (forecast.end - forecast.start) / STEP) * STEP);
  showMoment();
}
$('graph').addEventListener('pointerdown', event => { held = true; setPlaying(false); $('graph').setPointerCapture(event.pointerId); drag(event); });
$('graph').addEventListener('pointermove', event => { if (held) drag(event); });
for (const name of ['pointerup', 'pointercancel']) $('graph').addEventListener(name, () => { held = false; });
$('play').addEventListener('click', () => {
  if (!state?.forecast) return;
  if (!playing && moment >= state.forecast.forecastEnd) moment = state.forecast.start;
  pauseUntil = 0; ended = false; setPlaying(!playing);
});
$('zoom').addEventListener('click', () => { viewKm = viewKm === CLOSE ? WIDE : CLOSE; setZoomSign(); loadMap(); });
function setZoomSign() { $('zoomSign').setAttribute('d', viewKm === CLOSE ? 'M6 8.5h5' : 'M6 8.5h5M8.5 6v5'); }

// ---- The whole screen ----

async function show(index) {
  const town = TOWNS[index];
  $('place').textContent = town[0];
  $('statusbar').firstElementChild.textContent = clock(Date.now(), language);   // the pictures show the real time, so the minutes add up
  $('arrow').style.display = index === 0 ? '' : 'none';   // the first place stands for where you are
  const age = query.get('age');
  const text = await (await fetch(`${BASE}/latest${saved && age ? `?age=${age}` : ''}`)).text();
  const latest = { ...JSON.parse(text), bytes: text.length };
  const read = await forecastFor(BASE, latest, town[1], town[2]);
  const now = Date.now();
  if (read && apple) read.samples = read.samples.filter(s => s.date <= now + 60 * MINUTE);
  const forecast = read && forecastAt(now, read);
  if (!forecast) {
    $('headline').textContent = TEXT.couldNot; $('detail').textContent = ''; $('graph').innerHTML = ''; $('credit').textContent = '';
    state = null; return;
  }
  const said = copy(forecast, language), w = words(language);
  const old = now - read.run >= 20 * MINUTE;
  $('headline').textContent = said.headline;
  $('detail').textContent = old ? (language === 'nl' ? `Verwachting van ${clock(read.run, language)}` : `Forecast made ${clock(read.run, language)}`) : (said.detail ?? '');
  $('detail').className = !old && said.detailIsAboutRain ? 'rain' : '';
  $('credit').textContent = old ? TEXT.source : w.made(clock(read.run, language));
  if (apple) $('credit').innerHTML = `<b>\uF8FFWeather</b> ${clock(read.run, language)} <u>${language === 'nl' ? 'Juridisch' : 'Legal'}</u>`;
  phone.classList.toggle('nomap', apple);
  phone.classList.toggle('due', forecast.hasRain && variant !== 'map');
  const graphWidth = $('graph').clientWidth - 40;
  const plot = variant === 'line' ? 250 : variant === 'ring' ? 56 : apple ? 200 : 92;
  $('graph').innerHTML = drawGraph(forecast, said, language, { width: graphWidth, plot, marker: !apple, colours: COLOURS[theme], dotFrom: 5 });
  $('ring').innerHTML = variant === 'ring' ? drawRing(forecast, said, language, { size: 300, colours: COLOURS[theme] }) : '';
  $('radarButton').textContent = TEXT.radar;
  state = { town, latest, forecast, said, graphWidth };
  moment = forecast.start;
  // Close in when rain is due here, to watch it arrive; wide when it is not, to see where the rain is.
  viewKm = Number(query.get('km')) || (forecast.hasRain ? CLOSE : WIDE);
  setZoomSign();
  const still = apple || playMode === 'rest' || matchMedia('(prefers-reduced-motion: reduce)').matches || variant === 'line' || variant === 'ring';
  setPlaying(!still);
  pauseUntil = performance.now() + 1500;
  // ?still=20 holds the screen as it is 20 minutes into playing, for pictures.
  if (query.has('still')) { moment = Math.min(forecast.forecastEnd, forecast.start + Number(query.get('still')) * MINUTE); setPlaying(true); held = true; }
  showMoment();
  if (variant !== 'line' && variant !== 'ring' && !apple) await loadMap();
  document.body.dataset.ready = '1';
}

const select = $('places');
TOWNS.forEach((town, index) => select.add(new Option(index === 0 ? `${town[0]} (${language === 'nl' ? 'waar je bent' : 'where you are'})` : town[0], index)));
select.value = query.get('place') ?? 0;
select.addEventListener('change', () => show(Number(select.value)));

// The prototype's own menu, behind the About button.
const link = (label, changes) => {
  const next = new URLSearchParams(location.search);
  for (const [key, value] of Object.entries(changes)) value === null ? next.delete(key) : next.set(key, value);
  return `<a href="?${next}">${label}</a>`;
};
$('links').innerHTML = [
  '<h3>Forecast</h3>',
  link('Now, live from KNMI', { run: null, age: null, place: null }),
  link('A saved shower: rain in about 20 minutes', { run: 'saved', place: 0, age: null }),
  link('A saved shower: raining now', { run: 'saved', place: 1, age: null }),
  link('A saved shower: rain in about 50 minutes', { run: 'saved', place: 2, age: null }),
  link('The saved shower, forecast 35 minutes old', { run: 'saved', place: 0, age: 35 }),
  '<h3>Look</h3>',
  link(language === 'nl' ? 'English' : 'Nederlands', { lang: language === 'nl' ? 'en' : 'nl' }),
  link(theme === 'dark' ? 'Light' : 'Dark', { theme: theme === 'dark' ? 'light' : 'dark' }),
  '<h3>When it opens, the map</h3>',
  link('plays once, then rests on now', { play: null }), link('keeps playing', { play: 'loop' }), link('waits until asked', { play: 'rest' }),
  '<h3>Directions tried and dropped</h3>',
  link('The proposal', { v: null }), link('Map first', { v: 'map' }), link('The line alone', { v: 'line' }), link('The watch’s circle, large', { v: 'ring' }),
].join('');
$('info').addEventListener('click', () => { $('sheet').hidden = false; });
$('closeSheet').addEventListener('click', () => { $('sheet').hidden = true; });

requestAnimationFrame(tick);
show(Number(select.value)).catch(error => { $('headline').textContent = TEXT.couldNot; console.error(error); document.body.dataset.ready = 'failed'; });
