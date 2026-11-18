// Written by AI on 2026.11.18 by model claude fable 5.2. For the iPhone design prototype only.
// The app's line (Sources/RainGraph/RainCurve.swift, as in site/rain.js), drawn at phone and widget sizes.
import { clock, words, display } from './rain.js';

const MINUTE = 60_000, STEP = 5 * MINUTE;

export const COLOURS = {
  dark: { bg: '#000000', text: '#FFFFFF', secondary: 'rgba(235,235,245,.62)', tertiary: 'rgba(235,235,245,.34)', rain: '#5A9BD3', rainText: '#6CAAE0', fill: [0.75, 0.22], baseline: 'rgba(255,255,255,.38)', grid: 'rgba(255,255,255,.16)' },
  light: { bg: '#FFFFFF', text: '#000000', secondary: 'rgba(60,60,67,.68)', tertiary: 'rgba(60,60,67,.36)', rain: '#5A9BD3', rainText: '#2A6CB0', fill: [0.75, 0.22], baseline: 'rgba(0,0,0,.3)', grid: 'rgba(0,0,0,.14)' },
  // The Lock Screen has no colour: opaque greys, as Apple asks for its vibrant mode. Rain is the only thing drawn above the line.
  lock: { bg: 'transparent', text: '#FFFFFF', secondary: '#A6A6A6', tertiary: '#7A7A7A', rain: '#FFFFFF', rainText: '#FFFFFF', fill: [0.5, 0.5], baseline: '#8A8A8A', grid: '#5A5A5A' },
  // StandBy at night: everything in red.
  night: { bg: 'transparent', text: '#FF2A1F', secondary: 'rgba(255,42,31,.8)', tertiary: 'rgba(255,42,31,.6)', rain: '#FF2A1F', rainText: '#FF2A1F', fill: [0.5, 0.5], baseline: 'rgba(255,42,31,.6)', grid: 'rgba(255,42,31,.25)' },
};

export function curvePoints(forecast, subdivisions = 10) {
  const steps = forecast.steps, values = steps.map(s => display(s.height));
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
      const v = (2 * s3 - 3 * s2 + 1) * values[k] + (s3 - 2 * s2 + s) * h * tangents[k] + (-2 * s3 + 3 * s2) * values[k + 1] + (s3 - s2) * h * tangents[k + 1];
      result.push([Math.min(t0 + s * h, 1), Math.max(0, v)]);
    }
  }
  if (result.at(-1)[0] < stop) result.push([stop, values[n - 1]]);
  return result.filter(p => p[0] <= stop);
}

export function wetRuns(points) {
  const runs = [];
  let run = [], lastDry = null;
  for (const point of points) {
    if (point[1] > 0.0005) { if (!run.length) run.push([lastDry ? lastDry[0] : point[0], 0]); run.push(point); }
    else { if (run.length) { run.push([point[0], 0]); runs.push(run); run = []; } lastDry = point; }
  }
  if (run.length) runs.push([...run, [run.at(-1)[0], 0]]);
  return runs;
}

let serial = 0;

/**
 * The two hours as SVG. `plot` is the height rain can reach. A dry forecast gets a bare axis, as in the app.
 * labels: 'half' (every half hour), 'hour', or 'none'. scale: the Light and Heavy lines. marker: the moving hairline.
 */
export function drawGraph(forecast, said, language, { width, plot, colours = COLOURS.dark, labels = 'half', scale = true, marker = false, font = 12, stroke = 2.5, dot = 5.5, dryPlot = 30, dotFrom = 15, family = '-apple-system, SF Pro Text, system-ui' }) {
  const dry = !forecast.hasRain, w = words(language), c = colours, id = `fill${serial++}`;
  const showScale = scale && !dry, top = showScale ? font + 6 : marker ? 12 : Math.ceil(stroke / 2);
  const P = dry ? Math.min(plot, dryPlot) : plot, base = top + P, labelled = labels !== 'none', H = base + (labelled ? font + 12 : dot + 3);
  const x = position => position * width, y = v => base - v * P;
  const path = points => points.map((p, i) => `${i ? 'L' : 'M'}${x(p[0]).toFixed(1)} ${y(p[1]).toFixed(1)}`).join('');
  const text = (at, anchor, string, fill = c.secondary, row = base + font + 8) => `<text x="${at}" y="${row}" text-anchor="${anchor}" font-family="${family}" font-size="${font}" fill="${fill}">${string}</text>`;
  const parts = [`<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c.rain}" stop-opacity="${c.fill[0]}"/><stop offset="1" stop-color="${c.rain}" stop-opacity="${c.fill[1]}"/></linearGradient></defs>`];
  for (const [mark, label] of showScale ? [[25, w.light], [75, w.heavy]] : []) {
    const at = y(display(mark));
    parts.push(`<line x1="0" x2="${width}" y1="${at}" y2="${at}" stroke="${c.grid}" stroke-dasharray="1 4"/>`, text(width, 'end', label, c.tertiary, at - 5));
  }
  for (const run of wetRuns(curvePoints(forecast))) {
    parts.push(`<path d="${path(run)}Z" fill="url(#${id})"/>`,
      `<path d="${path(run.slice(1, -1))}" fill="none" stroke="${c.rain}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round"/>`);
  }
  // Past where the forecast stops the baseline is dotted: no forecast yet, not dry.
  const known = x(Math.min(1, forecast.position(forecast.forecastEnd)));
  parts.push(`<line x1="0" x2="${known}" y1="${base}" y2="${base}" stroke="${c.baseline}" stroke-width="1.5"/>`);
  if (forecast.end - forecast.forecastEnd >= dotFrom * MINUTE)
    parts.push(`<line x1="${known + 4}" x2="${width}" y1="${base}" y2="${base}" stroke="${c.baseline}" stroke-width="2" stroke-linecap="round" stroke-dasharray="0.1 6"/>`);
  if (labelled) {
    const nowWidth = font * 2.6;
    parts.push(text(0, 'start', language === 'nl' ? 'Nu' : 'Now'));
    const every = (labels === 'half' ? 30 : 60) * MINUTE, half = 30 * MINUTE, labelWidth = font * 2.9;
    for (let tick = Math.floor(forecast.start / half + 1) * half; tick <= forecast.end; tick += half) {
      const at = x(forecast.position(tick)), whole = tick % (60 * MINUTE) === 0;
      if (labels === 'hour' && !whole) continue;
      parts.push(`<line x1="${at}" x2="${at}" y1="${base}" y2="${base + (whole ? 6 : 4)}" stroke="${c.baseline}" stroke-width="1.5"/>`);
      if (tick % every) continue;
      if (at > nowWidth + labelWidth / 2 + 4 && at < width - labelWidth / 2) parts.push(text(at, 'middle', clock(tick, language)));
      else if (at >= width - labelWidth / 2) parts.push(text(width, 'end', clock(tick, language)));
    }
  }
  if (said.change) {
    const at = x(forecast.position(said.change));
    parts.push(`<circle cx="${at}" cy="${base}" r="${dot + 3}" fill="${c.bg === 'transparent' ? '#000' : c.bg}" ${c.bg === 'transparent' ? 'style="mix-blend-mode:destination-out"' : ''}/><circle cx="${at}" cy="${base}" r="${dot}" fill="${c.text}"/>`);
  }
  if (marker) parts.push(`<g id="marker"><line y1="${top - 6}" y2="${base}" stroke="${c.text}" stroke-width="1.5" stroke-linecap="round"/><rect x="-3" y="${top - 12}" width="6" height="14" rx="3" fill="${c.text}"/></g>`);
  return `<svg width="${width}" height="${H}" viewBox="0 0 ${width} ${H}" style="display:block;overflow:visible">${parts.join('')}</svg>`;
}

/** The watch's circle: { lead, number, unit } as the watch words them (REQUIREMENTS.md, "Words"). */
export function circleWords(forecast, said, language) {
  const nl = language === 'nl';
  if (!forecast.hasRain) return { lead: nl ? 'Droog' : 'Dry', number: null, unit: `${forecast.minutesKnown >= 120 ? '2+' : '1+'} ${nl ? 'UUR' : 'HRS'}` };
  const raining = forecast.spells[0].isRain, minutes = said.change ? Math.max(1, Math.round((said.change - forecast.now) / MINUTE)) : null;
  const long = minutes === null || minutes >= 60;
  return { lead: raining ? (nl ? 'NOG' : 'FOR') : (nl ? 'OVER' : 'IN'), number: long ? (minutes === null && forecast.minutesKnown >= 120 ? '2+' : '1+') : String(minutes), unit: long ? (nl ? 'UUR' : 'HRS') : 'MIN' };
}

/** The watch's circle at any size: a 240° track, rain rising outwards from it, a dot at the change. */
export function drawRing(forecast, said, language, { size = 300, colours = COLOURS.dark, plate = null, track = 0.7, rim = 0.97, weight = 0.045, family = 'SF Pro Rounded, -apple-system, system-ui', sizes = [0.1, 0.34, 0.1] } = {}) {
  const c = colours, R = size / 2, radius = R * track, reach = R * (rim - track), start = 150, sweep = 240;
  const polar = (r, position) => { const a = (start + position * sweep) * Math.PI / 180; return [R + r * Math.cos(a), R + r * Math.sin(a)]; };
  const arc = (r, from, to) => { const [x0, y0] = polar(r, from), [x1, y1] = polar(r, to); return `M${x0.toFixed(2)} ${y0.toFixed(2)}A${r} ${r} 0 ${(to - from) * sweep > 180 ? 1 : 0} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`; };
  const known = Math.min(1, forecast.position(forecast.forecastEnd)), w = circleWords(forecast, said, language);
  const parts = [];
  if (plate) parts.push(`<circle cx="${R}" cy="${R}" r="${R}" fill="${plate}"/>`);
  if (forecast.hasRain) {
    parts.push(`<path d="${arc(radius, 0, known)}" fill="none" stroke="${c.baseline}" stroke-width="${Math.max(2, size * weight)}" stroke-linecap="round"/>`);
    for (const run of wetRuns(curvePoints(forecast))) {
      const outer = run.map(p => polar(radius + p[1] * reach, p[0])), inner = run.map(p => polar(radius - size * weight / 2, p[0])).reverse();
      parts.push(`<path d="M${[...outer, ...inner].map(p => p.map(v => v.toFixed(2)).join(' ')).join('L')}Z" fill="${c.rain}"/>`);
    }
    if (said.change) { const [x, y] = polar(radius, forecast.position(said.change)); parts.push(`<circle cx="${x}" cy="${y}" r="${size * 0.075}" fill="${plate ? '#1c1c1e' : c.bg}"/><circle cx="${x}" cy="${y}" r="${size * 0.05}" fill="${c.text}"/>`); }
  }
  const text = (string, y, px, fill, weightOf = 600) => `<text x="${R}" y="${y}" text-anchor="middle" font-family="${family}" font-weight="${weightOf}" font-size="${px}" fill="${fill}">${string}</text>`;
  const [lead, number, unit] = sizes.map(v => v * size);
  if (w.number === null) parts.push(text(w.lead, R + number * 0.05, number * 0.62, c.text), text(w.unit, R + number * 0.05 + unit * 1.35, unit * 1.1, c.secondary));
  else parts.push(text(w.lead, R - number * 0.47, lead, forecast.hasRain ? c.rainText : c.text),
    text(w.number, R + number * 0.36, number, c.text),
    text(w.unit, R + number * 0.36 + unit * 1.25, unit, c.rainText));
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="display:block;overflow:visible">${parts.join('')}</svg>`;
}
