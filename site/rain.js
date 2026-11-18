// Written by AI on 2026.11.18 by model claude fable 5.2. A prototype for the website proposal.
// Reads one place's forecast the way the watch does (server/watch_client.py) and words and draws it
// the way the app does (Sources/RainGraph: Forecast, RainCopy, RainCurve, RainChart). If the app's
// rules change, change this too.

const MINUTE = 60_000, STEP = 5 * MINUTE, WINDOW = 120 * MINUTE;

// ---- The server's two files ----

export function cell(latitude, longitude) {
  const a = 6378.137, b = 6356.752, e = Math.sqrt(1 - (b / a) ** 2), rad = Math.PI / 180;
  const t = phi => Math.tan(Math.PI / 4 - phi / 2) / ((1 - e * Math.sin(phi)) / (1 + e * Math.sin(phi))) ** (e / 2);
  const north = 60 * rad;
  const rho = a * Math.cos(north) / Math.sqrt(1 - (e * Math.sin(north)) ** 2) * t(latitude * rad) / t(north);
  return { row: Math.floor(rho * Math.cos(longitude * rad) - 3650), column: Math.floor(rho * Math.sin(longitude * rad)) };
}

export async function readLatest(base) {
  const response = await fetch(`${base}/latest`);
  if (!response.ok) throw new Error(`latest: ${response.status}`);
  const text = await response.text();
  return { ...JSON.parse(text), bytes: text.length };
}

export function squareOf(latest, { row, column }) {
  if (!(row >= 0 && row < 765 && column >= 0 && column < 700)) return null;
  const size = latest.square_km;
  const index = Math.floor(row / size) * latest.columns + Math.floor(column / size);
  const first = latest.squares.slice(0, index).reduce((sum, n) => sum + Math.max(n, 0), 0);
  return { index, length: latest.squares[index], first };
}

/** { run, samples: [{ date, rate }], requests: [...] }, or null outside KNMI's grid. rate null is no data. */
export async function forecastFor(base, latest, latitude, longitude) {
  const place = cell(latitude, longitude), square = squareOf(latest, place);
  if (!square) return null;
  const size = latest.square_km, frames = latest.frames;
  const requests = [{ name: 'latest', bytes: latest.bytes }];
  let values;
  if (square.length === 0) values = new Uint8Array(frames);
  else if (square.length < 0) values = new Uint8Array(frames).fill(255);
  else {
    const last = square.first + square.length - 1;
    const response = await fetch(`${base}/${latest.pack}`, { headers: { Range: `bytes=${square.first}-${last}` } });
    if (response.status !== 206) throw new Error(`square: ${response.status}`);
    const packed = await response.arrayBuffer();
    if (packed.byteLength !== square.length) throw new Error(`square: ${packed.byteLength} bytes, not ${square.length}`);
    const inflated = new Uint8Array(await new Response(
      new Blob([packed]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer());
    const width = Math.min(size, 700 - Math.floor(place.column / size) * size);
    const at = ((place.row % size) * width + place.column % size) * frames;
    values = inflated.slice(at, at + frames);
    requests.push({ name: latest.pack, first: square.first, last, bytes: square.length });
  }
  const run = Date.parse(latest.run);
  const samples = [...values].map((v, k) => ({
    date: run + (latest.first_frame_minutes + k * latest.step_minutes) * MINUTE,
    rate: v === 255 ? null : v === 0 ? 0 : 0.1 * 10 ** ((v - 1) / 50),
  }));
  return { run, samples, requests, square };
}

// ---- The app's forecast (Forecast.swift, Snapshot.swift) ----

const height = rate => rate <= 0 ? 0 : rate <= 2 ? 20 * rate : Math.min(100, 40 + (rate - 2) * 3.75);
const rateOf = h => h <= 0 ? 0 : h <= 40 ? h / 20 : 2 + (h - 40) / 3.75;
/** Drawn height 0 to 1: full at Buienradar's Heavy line, any rain at least 6%. */
export const display = h => h <= 0 ? 0 : Math.max(0.06, Math.min(1, rateOf(h) / rateOf(75)) ** 0.75);

/** What is left of the run at `now`, or null when there is no data for now. Stale after an hour. */
export function forecastAt(now, { run, samples }) {
  if (now >= run + 60 * MINUTE) return null;
  const first = samples.findLastIndex(s => s.date <= now);
  if (first < 0) return null;
  const stop = samples[first].date + WINDOW, picked = [];
  for (const sample of samples.slice(first)) {
    if (sample.date > stop || sample.rate === null) break;
    picked.push({ ...sample, height: height(sample.rate), isRain: sample.rate > 0 });
  }
  if (!picked.length) return null;
  const start = picked[0].date, end = start + WINDOW, forecastEnd = Math.min(end, picked.at(-1).date);
  if (forecastEnd <= now) return null;
  const forecast = { samples: picked, now, start, end, forecastEnd, position: date => (date - start) / WINDOW };
  forecast.steps = picked.filter(s => s.date < forecastEnd);
  forecast.hasRain = forecast.steps.some(s => s.isRain);
  forecast.minutesKnown = Math.max(0, Math.floor((forecastEnd - now) / MINUTE));
  forecast.spells = spells(forecast);
  return forecast;
}

function spells({ steps, forecastEnd }) {
  const all = [];
  for (const s of steps) {
    const end = Math.min(s.date + STEP, forecastEnd), last = all.at(-1);
    if (last && last.isRain === s.isRain) { last.end = end; last.peak = Math.max(last.peak, s.height); }
    else all.push({ isRain: s.isRain, start: s.date, end, peak: s.height });
  }
  // A dry gap under ten minutes between two wet stretches can't be used to go out: the words call it wet.
  for (let i = 1; i < all.length - 1;) {
    const gap = all[i];
    if (!gap.isRain && gap.end - gap.start < 10 * MINUTE) {
      all.splice(i - 1, 3, { isRain: true, start: all[i - 1].start, end: all[i + 1].end, peak: Math.max(all[i - 1].peak, all[i + 1].peak) });
      i = Math.max(1, i - 1);
    } else i++;
  }
  return all;
}

// ---- The app's words (RainCopy.swift, Localizable.xcstrings) ----

const WORDS = {
  en: {
    locale: 'en-GB', now: 'Now',
    reach: m => m >= 120 ? 'over 2 hours' : m >= 60 ? 'over an hour' : `over ${Math.max(5, Math.floor(m / 5) * 5)} min`,
    dryFor: r => `Dry for ${r}`, rainFor: r => `Rain for ${r}`,
    rainUntil: t => `Rain until ${t}`, dryUntil: t => `Dry until ${t}`,
    rainStops: m => `Rain stops in ${m} min`, dryMinutes: m => `Dry for ${m} min`,
    from: (what, t) => `${what} from ${t}`, dryFrom: t => `Dry from ${t}`, dry: 'Dry',
    heaviest: t => `Heaviest around ${t}`, intensity: ['Drizzle', 'Light rain', 'Rain', 'Heavy rain'],
    made: t => `KNMI forecast made ${t}`, tooOld: 'No Recent Forecast', last: t => `Last forecast ${t}`,
    unavailable: 'Forecast Unavailable', noneHere: 'No Forecast Here', light: 'Light', heavy: 'Heavy',
  },
  nl: {
    locale: 'nl-NL', now: 'Nu',
    reach: m => m >= 120 ? 'Ruim 2 uur' : m >= 60 ? 'Ruim een uur' : `Ruim ${Math.max(5, Math.floor(m / 5) * 5)} min`,
    dryFor: r => `${r} droog`, rainFor: r => `${r} regen`,
    rainUntil: t => `Regen tot ${t}`, dryUntil: t => `Droog tot ${t}`,
    rainStops: m => `Nog ${m} min regen`, dryMinutes: m => `Nog ${m} min droog`,
    from: (what, t) => `${what} vanaf ${t}`, dryFrom: t => `Droog vanaf ${t}`, dry: 'Droog',
    heaviest: t => `Het hardst rond ${t}`, intensity: ['Motregen', 'Lichte regen', 'Regen', 'Zware regen'],
    made: t => `KNMI-verwachting ${t}`, tooOld: 'Verwachting te oud', last: t => `Laatste verwachting ${t}`,
    unavailable: 'Geen verwachting', noneHere: 'Hier geen verwachting', light: 'Licht', heavy: 'Zwaar',
  },
};
export const words = language => WORDS[language];

export function clock(date, language) {
  return new Date(date).toLocaleTimeString(WORDS[language].locale, { hour: '2-digit', minute: '2-digit' });
}

/** { headline, detail, detailIsAboutRain, change } in the app's words. */
export function copy(forecast, language) {
  const w = WORDS[language], time = date => clock(date, language);
  const { spells, forecastEnd, now } = forecast, current = spells[0];
  const whole = spells.length === 1;
  const minutesLeft = whole ? null : Math.max(1, Math.round((current.end - now) / MINUTE));
  const change = whole ? null : current.end;
  const raining = current.isRain;
  const peak = forecast.steps.reduce((best, s) => s.height > best.height ? s : best, forecast.steps[0]);
  const peakPhrase = w.heaviest(time(peak.date));
  const phrase = spell => w.intensity[spell.peak >= 75 ? 3 : spell.peak >= 50 ? 2 : spell.peak >= 25 ? 1 : 0];

  let headline;
  if (!forecast.hasRain) headline = w.dryFor(w.reach(forecast.minutesKnown));
  else if (minutesLeft === null) headline = w.rainFor(w.reach(forecast.minutesKnown));
  else if (minutesLeft >= 60) headline = raining ? w.rainUntil(time(change)) : w.dryUntil(time(change));
  else headline = raining ? w.rainStops(minutesLeft) : w.dryMinutes(minutesLeft);

  let detail = null, detailIsAboutRain = false;
  if (forecast.hasRain) {
    const next = spells[1];
    if (!next) { detail = raining ? peakPhrase : null; detailIsAboutRain = raining; }
    else {
      const open = next.end >= forecastEnd, ends = open ? '' : `–${time(next.end)}`;
      if (next.isRain) {
        detail = open ? w.from(phrase(next), time(next.start)) : `${phrase(next)} ${time(next.start)}${ends}`;
        detailIsAboutRain = true;
      } else if (open && minutesLeft >= 60) { detail = peakPhrase; detailIsAboutRain = true; }
      else detail = open ? w.dryFrom(time(next.start)) : `${w.dry} ${time(next.start)}${ends}`;
    }
  }
  return { headline, detail, detailIsAboutRain, change };
}

// ---- The app's line (RainCurve.swift) ----

/** Points along the curve as [time 0…1, height 0…1]: a monotone cubic through each step's height. */
function points(forecast, subdivisions = 10) {
  const { steps } = forecast;
  const values = steps.map(s => display(s.height));
  const times = steps.map(s => forecast.position(s.date + STEP / 2));
  const stop = Math.min(1, forecast.position(forecast.forecastEnd));
  if (values.length < 2) return values.length ? [[0, values[0]], [stop, values[0]]] : [];
  const n = values.length;
  const slopes = Array.from({ length: n - 1 }, (_, k) => (values[k + 1] - values[k]) / (times[k + 1] - times[k]));
  const tangents = new Array(n).fill(0);
  for (let k = 1; k < n - 1; k++) tangents[k] = slopes[k - 1] * slopes[k] <= 0 ? 0 : (slopes[k - 1] + slopes[k]) / 2;
  for (let k = 0; k < n - 1; k++) {
    if (slopes[k] === 0) continue;
    const a = tangents[k] / slopes[k], b = tangents[k + 1] / slopes[k], length = Math.hypot(a, b);
    if (length > 3) { tangents[k] = 3 / length * a * slopes[k]; tangents[k + 1] = 3 / length * b * slopes[k]; }
  }
  const result = [[0, values[0]], [times[0], values[0]]];
  for (let k = 0; k < n - 1; k++) {
    const t0 = times[k], h = times[k + 1] - t0;
    for (let step = 1; step <= subdivisions; step++) {
      const s = step / subdivisions, s2 = s * s, s3 = s2 * s;
      const v = (2 * s3 - 3 * s2 + 1) * values[k] + (s3 - 2 * s2 + s) * h * tangents[k]
        + (-2 * s3 + 3 * s2) * values[k + 1] + (s3 - s2) * h * tangents[k + 1];
      result.push([Math.min(t0 + s * h, 1), Math.max(0, v)]);
    }
  }
  if (result.at(-1)[0] < stop) result.push([stop, values[n - 1]]);
  return result.filter(p => p[0] <= stop);
}

/** The curve cut into its wet stretches, each starting and ending on the baseline. */
function wetRuns(forecast) {
  const runs = [];
  let run = [], lastDry = null;
  for (const point of points(forecast)) {
    if (point[1] > 0.0005) {
      if (!run.length) run.push([lastDry ? lastDry[0] : point[0], 0]);
      run.push(point);
    } else {
      if (run.length) { run.push([point[0], 0]); runs.push(run); run = []; }
      lastDry = point;
    }
  }
  if (run.length) runs.push([...run, [run.at(-1)[0], 0]]);
  return runs;
}

/** Whole clock hours inside the window. */
function hourMarks(forecast) {
  const marks = [];
  for (let hour = Math.floor(forecast.start / 3_600_000 + 1) * 3_600_000; hour <= forecast.end; hour += 3_600_000) marks.push(hour);
  return marks;
}

// ---- The app's graph (RainChart, ForecastChart) ----

/** The graph `width` wide: { width, height, shapes (SVG), labels: [{ x, y, anchor, text }] }. */
export function chart(forecast, said, language, width) {
  // As in the app, a dry forecast gets a bare axis: no scale lines over nothing.
  const dry = !forecast.hasRain;
  const w = WORDS[language], W = width, plot = dry ? 40 : W < 600 ? 120 : 190, top = dry ? 0 : 22, base = top + plot, H = base + 30;
  const x = position => position * W, y = v => base - v * plot;
  const path = points => points.map((p, i) => `${i ? 'L' : 'M'}${x(p[0]).toFixed(1)} ${y(p[1]).toFixed(1)}`).join('');
  const line = 'stroke="#fff" stroke-opacity=".38"';
  const shapes = ['<defs><linearGradient id="fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5A9BD3" stop-opacity=".8"/><stop offset="1" stop-color="#5A9BD3" stop-opacity=".25"/></linearGradient></defs>'];
  const labels = [];
  // The app's graph labels the Light and Heavy lines at the far end, where rain matters least.
  for (const [mark, label] of dry ? [] : [[25, w.light], [75, w.heavy]]) {
    const at = y(display(mark));
    shapes.push(`<line x1="0" x2="${W}" y1="${at}" y2="${at}" stroke="#fff" stroke-opacity=".16" stroke-dasharray="1 4"/>`);
    labels.push({ x: W, y: at - 6, anchor: 'end', text: label });
  }
  for (const run of wetRuns(forecast)) {
    shapes.push(`<path d="${path(run)}Z" fill="url(#fill)"/>`,
      `<path d="${path(run.slice(1, -1))}" fill="none" stroke="#5A9BD3" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>`);
  }
  // Past where the forecast stops the baseline is dotted: no forecast yet, not dry.
  const known = x(Math.min(1, forecast.position(forecast.forecastEnd)));
  shapes.push(`<line x1="0" x2="${known}" y1="${base}" y2="${base}" ${line} stroke-width="1.5"/>`);
  if (forecast.end - forecast.forecastEnd > 10 * MINUTE)
    shapes.push(`<line x1="${known + 4}" x2="${W}" y1="${base}" y2="${base}" ${line} stroke-width="2" stroke-linecap="round" stroke-dasharray="0.1 6"/>`);
  labels.push({ x: 0, y: base + 24, anchor: 'start', text: w.now });
  for (const hour of hourMarks(forecast)) {
    const at = x(forecast.position(hour));
    shapes.push(`<line x1="${at}" x2="${at}" y1="${base}" y2="${base + 6}" ${line} stroke-width="1.5"/>`);
    // "Now" ends about 40 px in; an hour label any closer reads as "Now 14:00".
    if (at > 70) labels.push({ x: Math.min(at, W), y: base + 24, anchor: at > W - 30 ? 'end' : 'middle', text: clock(hour, language) });
  }
  if (said.change) {
    const at = x(forecast.position(said.change));
    shapes.push(`<circle cx="${at}" cy="${base}" r="9" fill="#000"/><circle cx="${at}" cy="${base}" r="5.5" fill="#fff"/>`);
  }
  return { width: W, height: H, shapes: shapes.join(''), labels };
}
