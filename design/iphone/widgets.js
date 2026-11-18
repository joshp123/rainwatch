// Written by AI on 2026.11.18 by model claude fable 5.2. The widget design bench (widgets.html).
import { forecastFor, forecastAt, copy, clock } from './rain.js';
import { drawGraph, drawRing, COLOURS } from './draw.js';

const MINUTE = 60_000;
const language = new URLSearchParams(location.search).get('lang') === 'nl' ? 'nl' : 'en';
const nl = language === 'nl';

async function forecastOf(latitude, longitude, age) {
  const text = await (await fetch(`/saved/latest${age ? `?age=${age}` : ''}`)).text();
  const latest = { ...JSON.parse(text), bytes: text.length };
  const read = await forecastFor('/saved', latest, latitude, longitude);
  const forecast = read && forecastAt(Date.now(), read);
  return forecast && { forecast, said: copy(forecast, language), run: read.run, old: Date.now() - read.run >= 20 * MINUTE };
}

// A place with no rain in the saved run, found by looking.
async function dryPlace() {
  for (const [latitude, longitude] of [[51.44, 5.47], [50.85, 5.69], [51.92, 4.48], [52.09, 5.12], [51.5, 3.61], [52.37, 4.89], [50.85, 4.35], [49.61, 6.13]]) {
    const found = await forecastOf(latitude, longitude);
    if (found && !found.forecast.hasRain) return found;
  }
  return null;
}

// The number stays with its unit when a headline takes two lines.
const bound = text => text.replace(/(\d+|an) (min|hour)/g, '$1\u00A0$2');
const made = state => nl ? `Verwachting van ${clock(state.run, language)}` : `Forecast made ${clock(state.run, language)}`;
const arrow = '<svg viewBox="0 0 16 16" width="10" height="10"><path d="M14.6 1.4 1.9 6.7c-.5.2-.4.9.1 1l5 1.3 1.3 5c.1.5.8.6 1 .1L14.6 1.4Z" fill="currentColor"/></svg>';
const drop = fill => `<svg viewBox="0 0 16 16" width="13" height="13" style="vertical-align:-1.5px"><path d="M13.6 2.4 3.2 6.7c-.4.2-.4.8.1.9l4 1.1 1.1 4c.1.5.7.5.9.1L13.6 2.4Z" fill="${fill}"/><path d="M2.2 2.2l11.6 11.6" stroke="${fill}" stroke-width="1.6" stroke-linecap="round"/></svg>`;
const PROBLEM = nl ? { title: 'Locatie uit', action: 'Tik om aan te zetten', circle: ['Geen', 'PLEK'] } : { title: 'Location off', action: 'Tap to turn on', circle: ['No', 'PLACE'] };

function rect(state, colours = COLOURS.lock) {
  if (!state) return `<div class="rect"><div class="h">${drop('#fff')} ${PROBLEM.title}</div><div class="s">${PROBLEM.action}</div></div>`;
  const { forecast, said, old } = state;
  const graph = drawGraph(forecast, said, language, { width: 152, plot: old ? 22 : 22, colours, labels: old ? 'none' : 'hour', scale: false, font: 11, stroke: 2, dot: 3.5, dryPlot: 14 });
  return `<div class="rect"><div class="h">${said.headline}</div>${old ? `<div class="s">${made(state)}</div>` : ''}<div style="margin-top:${old ? 4 : forecast.hasRain ? 3 : 11}px">${graph}</div></div>`;
}

function circle(state, colours = COLOURS.lock) {
  const plate = 'rgba(255,255,255,.16)';
  if (!state) return `<div class="circle"><svg width="72" height="72"><circle cx="36" cy="36" r="36" fill="${plate}"/><text x="36" y="34" text-anchor="middle" font-family="SF Pro Rounded" font-weight="600" font-size="17" fill="#fff">${PROBLEM.circle[0]}</text><text x="36" y="49" text-anchor="middle" font-family="SF Pro Rounded" font-weight="600" font-size="11" fill="#A6A6A6">${PROBLEM.circle[1]}</text></svg></div>`;
  return `<div class="circle">${drawRing(state.forecast, state.said, language, { size: 72, colours, plate, track: 0.7, rim: 0.98, weight: 0.04, sizes: [0.135, 0.33, 0.135] })}</div>`;
}

function small(state, town, colours = COLOURS.dark, background = true) {
  const where = `<div class="where">${arrow}${town}</div>`;
  if (!state) return `<div class="small dryb">${`<div class="h" style="margin-top:0">${PROBLEM.title}</div><div class="s">${PROBLEM.action}</div>`}</div>`;
  const { forecast, said, old } = state;
  const graph = drawGraph(forecast, said, language, { width: 126, plot: 30, colours, labels: old ? 'none' : 'hour', scale: false, font: 11, stroke: 2, dot: 4, dryPlot: 16 });
  return `<div class="small ${background ? (forecast.hasRain ? 'wet' : 'dryb') : ''}" style="color:${colours.text}">${background ? where : ''}<div class="h">${bound(said.headline)}</div>${old ? `<div class="s" style="color:${colours.secondary}">${made(state)}</div>` : ''}<div class="grow"></div>${graph}</div>`;
}

function medium(state, town) {
  const { forecast, said, old } = state;
  const graph = drawGraph(forecast, said, language, { width: 306, plot: 34, colours: COLOURS.dark, labels: 'half', scale: false, font: 11, stroke: 2.5, dot: 4.5, dryPlot: 16 });
  const second = old ? made(state) : said.detail ?? '';
  return `<div class="medium ${forecast.hasRain ? 'wet' : 'dryb'}"><div class="where">${arrow}${town}</div><div class="h">${said.headline}</div><div class="s ${!old && said.detailIsAboutRain ? 'rain' : ''}">${second}</div><div class="grow"></div>${graph}</div>`;
}

const lock = (state, label, photo = false) => `<div class="cell"><div class="lock ${photo ? 'photo' : ''}"><div class="inline">${nl ? 'wo 18' : 'Wed 18'}&ensp;${state ? state.said.headline : PROBLEM.title}</div><div class="time">${clock(Date.now(), language)}</div><div class="slots">${rect(state)}${circle(state)}</div></div><span>${label}</span></div>`;

const states = {
  coming: await forecastOf(53.10, 6.25), raining: await forecastOf(53.25, 6.00), later: await forecastOf(51.40, 4.60),
  dry: await dryPlace(), old: await forecastOf(53.10, 6.25, 35),
};
const names = { coming: 'Rain on the way', raining: 'Raining', later: 'Rain later', dry: 'No rain', old: 'Forecast over 20 minutes old' };

document.getElementById('out').innerHTML = `
<h2>Lock Screen: the line above the clock, the wide slot and the circle (no colour there)</h2>
<div class="row">${Object.keys(states).map(k => lock(states[k], names[k])).join('')}${lock(null, 'Location off')}${lock(states.coming, 'On a light photo', true)}</div>
<h2>Home Screen: small</h2>
<div class="row">${Object.keys(states).map(k => `<div class="cell">${small(states[k], 'Eindhoven')}<span>${names[k]}</span></div>`).join('')}<div class="cell">${small(null)}<span>Location off</span></div></div>
<h2>Home Screen: medium</h2>
<div class="row">${Object.keys(states).map(k => `<div class="cell">${medium(states[k], 'Eindhoven')}<span>${names[k]}</span></div>`).join('')}</div>
<h2>StandBy: the small widget without its background, and at night</h2>
<div class="row"><div class="standby">${small(states.coming, '', COLOURS.dark, false)}${small(states.coming, '', COLOURS.night, false)}</div></div>`;
document.body.dataset.ready = '1';
