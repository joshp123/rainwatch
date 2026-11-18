// Written by AI on 2026.11.18 by model claude fable 5.2. For the iPhone design prototype only.
// Reads the squares of KNMI's 1 km grid under a map and paints one frame of rain, the way the watch's
// radar page does (App/Rain/RadarPage.swift, Painter). If the app's drawing changes, change this too.

const rad = Math.PI / 180;

/** A point on KNMI's grid, in cells: x is the column, y the row (site/rain.js `cell`, not rounded). */
export function gridPoint(latitude, longitude) {
  const a = 6378.137, b = 6356.752, e = Math.sqrt(1 - (b / a) ** 2);
  const t = phi => Math.tan(Math.PI / 4 - phi / 2) / ((1 - e * Math.sin(phi)) / (1 + e * Math.sin(phi))) ** (e / 2);
  const north = 60 * rad;
  const rho = a * Math.cos(north) / Math.sqrt(1 - (e * Math.sin(north)) ** 2) * t(latitude * rad) / t(north);
  return { x: rho * Math.sin(longitude * rad), y: rho * Math.cos(longitude * rad) - 3650 };
}

const mercator = latitude => Math.log(Math.tan(Math.PI / 4 + latitude * rad / 2));
const latitudeOf = y => (2 * Math.atan(Math.exp(y)) - Math.PI / 2) / rad;

/** The map picture's geometry: where each of its points is on the earth. */
export function mapGeometry(centre, ptPerDegLon, width, height) {
  const perRadian = ptPerDegLon / rad, y0 = mercator(centre.latitude);
  return {
    width, height,
    coordinate: (x, y) => ({ longitude: centre.longitude + (x - width / 2) / ptPerDegLon, latitude: latitudeOf(y0 - (y - height / 2) / perRadian) }),
    point: ({ latitude, longitude }) => ({ x: width / 2 + (longitude - centre.longitude) * ptPerDegLon, y: height / 2 - (mercator(latitude) - y0) * perRadian }),
  };
}

/** Every square the map touches, fetched with one range request per row of squares, as the watch does. */
export async function loadCells(base, latest, geometry) {
  const corners = [[0, 0], [geometry.width, 0], [0, geometry.height], [geometry.width, geometry.height]]
    .map(([x, y]) => geometry.coordinate(x, y)).map(c => gridPoint(c.latitude, c.longitude));
  const size = latest.square_km, frames = latest.frames;
  const clamp = (v, max) => Math.max(0, Math.min(max, v));
  const top = clamp(Math.floor(Math.min(...corners.map(c => c.y)) - 2), 764), bottom = clamp(Math.floor(Math.max(...corners.map(c => c.y)) + 2), 764);
  const left = clamp(Math.floor(Math.min(...corners.map(c => c.x)) - 2), 699), right = clamp(Math.floor(Math.max(...corners.map(c => c.x)) + 2), 699);
  const offsets = [0];
  for (const length of latest.squares) offsets.push(offsets.at(-1) + Math.max(length, 0));
  const squares = new Map();
  let requests = 0, bytes = 0;
  await Promise.all(Array.from({ length: Math.floor(bottom / size) - Math.floor(top / size) + 1 }, async (_, k) => {
    const squareRow = Math.floor(top / size) + k;
    const first = squareRow * latest.columns + Math.floor(left / size), last = squareRow * latest.columns + Math.floor(right / size);
    if (offsets[last + 1] === offsets[first]) return;
    const response = await fetch(`${base}/${latest.pack}`, { headers: { Range: `bytes=${offsets[first]}-${offsets[last + 1] - 1}` } });
    if (response.status !== 206) throw new Error(`squares: ${response.status}`);
    const packed = new Uint8Array(await response.arrayBuffer());
    requests++; bytes += packed.length;
    for (let index = first; index <= last; index++) {
      if (latest.squares[index] <= 0) continue;
      const part = packed.slice(offsets[index] - offsets[first], offsets[index + 1] - offsets[first]);
      squares.set(index, new Uint8Array(await new Response(new Blob([part]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer()));
    }
  }));
  const value = (row, column, frame) => {
    if (!(row >= 0 && row < 765 && column >= 0 && column < 700)) return 255;
    const index = Math.floor(row / size) * latest.columns + Math.floor(column / size), length = latest.squares[index];
    if (length === 0) return 0;
    if (length < 0) return 255;
    const square = squares.get(index);
    if (!square) return 255;
    const width = Math.min(size, 700 - Math.floor(column / size) * size);
    return square[((row % size) * width + column % size) * frames + frame];
  };
  return { value, requests, bytes, frames };
}

const smoothstep = (low, high, x) => { const t = Math.min(Math.max((x - low) / (high - low), 0), 1); return t * t * (3 - 2 * t); };
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];

// On a dark map: Buienradar's blue, brighter towards white as it gets heavier, red from 10 mm/h.
// On a light map white would vanish, so heavier rain is a deeper blue instead.
const RAMPS = {
  dark: { blue: [0.35, 0.61, 0.83], light: [0.62, 0.82, 1], strong: [0.93, 0.97, 1], red: [1, 0.3, 0.3], veil: [0.55, 0.55, 0.6] },
  light: { blue: [0.35, 0.61, 0.83], light: [0.2, 0.45, 0.78], strong: [0.09, 0.25, 0.6], red: [0.85, 0.12, 0.12], veil: [0.45, 0.45, 0.5] },
};

function colour(ramp, level, presence, missing) {
  const veilAlpha = 0.4 * missing;
  if (presence <= 0) return [...ramp.veil, veilAlpha];
  let c, opacity;
  if (level < 51) { c = mix(ramp.blue, ramp.light, smoothstep(1, 51, level)); opacity = 0.5 + 0.25 * smoothstep(1, 51, level); }
  else if (level < 86) { c = mix(ramp.light, ramp.strong, smoothstep(51, 86, level)); opacity = 0.75 + 0.2 * smoothstep(51, 86, level); }
  else { c = mix(ramp.strong, ramp.red, smoothstep(91, 101, level)); opacity = 0.95 + 0.05 * smoothstep(91, 101, level); }
  const a = presence * opacity, total = a + veilAlpha * (1 - a);
  if (total <= 0) return [0, 0, 0, 0];
  return [...c.map((v, i) => (v * a + ramp.veil[i] * veilAlpha * (1 - a)) / total), total];
}

function soften(grid, width, height) {
  const across = grid.slice();
  for (let row = 0; row < height; row++) for (let column = 1; column < width - 1; column++) {
    const i = row * width + column; across[i] = (grid[i - 1] + 2 * grid[i] + grid[i + 1]) / 4;
  }
  const down = across.slice();
  for (let row = 1; row < height - 1; row++) for (let column = 0; column < width; column++) {
    const i = row * width + column; down[i] = (across[i - width] + 2 * across[i] + across[i + width]) / 4;
  }
  return down;
}

/** A painter for one map: `paint(frame)` gives an ImageData `scale` pixels to the point. */
export function painter(cells, geometry, viewKm, theme, scale = 0.75, showCells = false) {
  const width = Math.round(geometry.width * scale), height = Math.round(geometry.height * scale);
  // The watch keeps a visible edge on each 1 km cell close up. A phone shows a kilometre twice as large,
  // where those edges read as blocks, so here the cells are always blended into each other.
  const close = showCells, ramp = RAMPS[theme];
  const points = new Float64Array(width * height * 2);
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (let row = 0; row < height; row++) for (let column = 0; column < width; column++) {
    const c = geometry.coordinate((column + 0.5) / scale, (row + 0.5) / scale), p = gridPoint(c.latitude, c.longitude);
    const i = (row * width + column) * 2;
    points[i] = p.x; points[i + 1] = p.y;
    minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x); minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
  }
  const top = Math.floor(minY - 1.5), left = Math.floor(minX - 1.5);
  const cellHeight = Math.floor(maxY + 1.5) - top + 1, cellWidth = Math.floor(maxX + 1.5) - left + 1;
  const DRY = -10;
  return {
    width, height,
    paint(frame) {
      let level = new Float32Array(cellWidth * cellHeight).fill(close ? 0 : DRY);
      let missing = new Float32Array(cellWidth * cellHeight), wet = new Float32Array(cellWidth * cellHeight);
      for (let row = 0; row < cellHeight; row++) for (let column = 0; column < cellWidth; column++) {
        const value = cells.value(top + row, left + column, frame), i = row * cellWidth + column;
        if (value === 255) missing[i] = 1; else if (value > 0) { level[i] = value; wet[i] = 1; }
      }
      if (!close) { level = soften(level, cellWidth, cellHeight); missing = soften(missing, cellWidth, cellHeight); }
      const image = new ImageData(width, height), pixels = image.data;
      for (let pixel = 0; pixel < width * height; pixel++) {
        const fx = points[pixel * 2] - 0.5 - left, fy = points[pixel * 2 + 1] - 0.5 - top;
        const x0 = Math.floor(fx), y0 = Math.floor(fy);
        if (x0 < 0 || y0 < 0 || x0 + 1 >= cellWidth || y0 + 1 >= cellHeight) continue;
        const tx = fx - x0, ty = fy - y0, i = y0 * cellWidth + x0;
        const blend = grid => (grid[i] * (1 - tx) + grid[i + 1] * tx) * (1 - ty) + (grid[i + cellWidth] * (1 - tx) + grid[i + cellWidth + 1] * tx) * ty;
        let presence, rain;
        if (close) { const share = blend(wet); presence = smoothstep(0.38, 0.62, share); rain = share > 0 ? blend(level) / share : 0; }
        else { rain = blend(level); presence = smoothstep(-4, 3, rain); }
        const [r, g, b, a] = colour(ramp, rain, presence, blend(missing));
        pixels[pixel * 4] = r * 255; pixels[pixel * 4 + 1] = g * 255; pixels[pixel * 4 + 2] = b * 255; pixels[pixel * 4 + 3] = a * 255;
      }
      return image;
    },
  };
}
