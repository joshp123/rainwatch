import React from "react";
import { appType, blue, grey, white } from "./theme";

/** One minute of the forecast as the exporter wrote it (export/, `Line`), from the app's own code. */
export type LineData = {
  minute: number;
  clock: string;
  runs: number[][][];
  known: number;
  dot: number | null;
  hours: string[][];
  hourAt: number[];
  now: string;
  grid: number[];
  words: { headline: string; detail: string | null; detailIsAboutRain: boolean; lead: string | null; value: string; unit: string | null };
};

/**
 * The rain line, drawn large: straight, as in the wide slot, when `bend` is 0, and round the
 * circle's 240 degree arc, as in the circle, when it is 1. Both shapes use the app's geometry
 * (RainViews.swift: CircularRainGauge and RainChart), so the bend ends where the real circle begins.
 */
export const RainShape: React.FC<{
  data: LineData;
  chart: { x: number; y: number; w: number; h: number };
  circle: { x: number; y: number; d: number };
  bend: number;
  /** How much of the line is drawn, left to right, 0 to 1. */
  draw?: number;
  /** The words, axis and grid of the straight graph, 0 to 1. */
  labels?: number;
  grid?: number;
}> = ({ data, chart, circle, bend, draw = 1, labels = 1, grid = 0 }) => {
  const half = circle.d / 2;
  // CircularRainGauge: the track at 0.6 of the radius, 3% of the width thick; rain from just
  // outside it out to 0.98, and any rain at least to the track's outer edge.
  const baseline = 0.57, floor = 0.63, rim = 0.98, track = 0.6;
  const straight = (t: number, v: number) => [chart.x + t * chart.w, chart.y - v * chart.h];
  const round = (t: number, v: number) => {
    const angle = ((150 + t * 240) * Math.PI) / 180;
    const base = v > 0.0005 ? floor : baseline;
    const r = half * (base + v * (rim - base));
    return [circle.x + r * Math.cos(angle), circle.y + r * Math.sin(angle)];
  };
  const at = (t: number, v: number) => {
    const [sx, sy] = straight(t, v);
    const [rx, ry] = round(t, v);
    return [sx + (rx - sx) * bend, sy + (ry - sy) * bend];
  };
  const path = (points: number[][]) => points.map(([t, v], i) => `${i ? "L" : "M"}${at(t, v).map((n) => n.toFixed(2)).join(" ")}`).join(" ");
  const along = (from: number, to: number) => {
    const points: number[][] = [];
    const steps = Math.max(2, Math.ceil(Math.abs(to - from) / 0.01));
    for (let i = 0; i <= steps; i++) points.push([from + ((to - from) * i) / steps, 0]);
    return points;
  };
  const shown = (points: number[][]) => points.filter(([t]) => t <= draw * data.known + 1e-6);

  // The app's stroke is 1.5 points on a graph about 170 points wide.
  const unit = chart.w / 170;
  const lineWidth = 1.5 * unit;
  const trackWidth = lineWidth + (circle.d * 0.03 - lineWidth) * bend;
  const known = data.known * draw;

  const areas = data.runs.map((run) => {
    const cut = shown(run);
    if (cut.length < 2) return "";
    const end = cut[cut.length - 1][0];
    return path([...cut, [end, 0], ...along(end, cut[0][0])]) + " Z";
  });
  const edges = data.runs.map((run) => {
    const cut = shown(run.slice(1, -1));
    return cut.length < 2 ? "" : path(cut);
  });
  const dot = data.dot !== null && data.dot <= known ? (() => {
    const [sx, sy] = straight(data.dot!, 0);
    const angle = ((150 + data.dot! * 240) * Math.PI) / 180;
    const [rx, ry] = [circle.x + half * track * Math.cos(angle), circle.y + half * track * Math.sin(angle)];
    return { x: sx + (rx - sx) * bend, y: sy + (ry - sy) * bend, r: (8 * 0.62 * unit * (1 - bend) + circle.d * 0.1 * 0.62 * bend) / 2 };
  })() : null;
  // Track, rain and dot follow the circle's radius exactly once bent.
  const trackPath = (() => {
    if (bend < 1) return path(along(0, known));
    const a0 = (150 * Math.PI) / 180, a1 = ((150 + known * 240) * Math.PI) / 180, r = half * track;
    return `M${circle.x + r * Math.cos(a0)} ${circle.y + r * Math.sin(a0)} A${r} ${r} 0 ${known * 240 > 180 ? 1 : 0} 1 ${circle.x + r * Math.cos(a1)} ${circle.y + r * Math.sin(a1)}`;
  })();

  const words = data.words;
  const fontUnit = unit;
  return (
    <>
      <svg style={{ position: "absolute", inset: 0, overflow: "visible" }} width="100%" height="100%">
        {grid > 0 && bend < 1
          ? data.grid.map((g) => (
              <line key={g} x1={chart.x} x2={chart.x + chart.w} y1={chart.y - g * chart.h} y2={chart.y - g * chart.h}
                stroke={white} strokeOpacity={0.22 * grid * (1 - bend)} strokeWidth={unit} strokeDasharray={`${unit} ${3 * unit}`} />
            ))
          : null}
        <path d={trackPath} fill="none" stroke={white} strokeOpacity={0.38} strokeWidth={trackWidth} strokeLinecap={bend > 0.5 ? "round" : "butt"} />
        {labels > 0 && bend < 1
          ? data.hourAt.map((x, i) => (x <= known ? (
              <line key={i} x1={chart.x + x * chart.w} x2={chart.x + x * chart.w} y1={chart.y} y2={chart.y + 4 * unit} stroke={white} strokeOpacity={0.38 * labels} strokeWidth={lineWidth} />
            ) : null))
          : null}
        {areas.map((d, i) => (d ? <path key={i} d={d} fill={blue} fillOpacity={0.55 + 0.45 * bend} /> : null))}
        {edges.map((d, i) => (d ? <path key={i} d={d} fill="none" stroke={blue} strokeOpacity={1 - bend} strokeWidth={lineWidth} strokeLinecap="round" strokeLinejoin="round" /> : null))}
        {dot ? (
          <>
            <circle cx={dot.x} cy={dot.y} r={dot.r * 1.9} fill="#000" fillOpacity={0.9} />
            <circle cx={dot.x} cy={dot.y} r={dot.r} fill={white} />
          </>
        ) : null}
      </svg>
      {labels > 0 && bend < 1 ? (
        <div style={{ position: "absolute", inset: 0, opacity: labels * (1 - bend * 2) }}>
          <div style={{ ...appType(16 * fontUnit), position: "absolute", left: chart.x, top: chart.y - chart.h - 34 * fontUnit, letterSpacing: `${0.6 * fontUnit}px`, whiteSpace: "nowrap" }}>
            {words.headline}
          </div>
          {words.detail ? (
            <div style={{ ...appType(13.5 * fontUnit, 500), color: words.detailIsAboutRain ? blue : grey, position: "absolute", left: chart.x, top: chart.y - chart.h - 15 * fontUnit, letterSpacing: `${0.6 * fontUnit}px`, whiteSpace: "nowrap" }}>
              {words.detail}
            </div>
          ) : null}
          <div style={{ ...appType(11 * fontUnit, 500), color: grey, position: "absolute", left: chart.x, top: chart.y + 6 * unit, letterSpacing: `${0.6 * fontUnit}px` }}>{data.now}</div>
          {data.hourAt.map((x, i) =>
            x * chart.w > 50 * unit && x <= known ? (
              <div key={i} style={{ ...appType(11 * fontUnit, 500), color: grey, position: "absolute", left: chart.x + x * chart.w, top: chart.y + 6 * unit, transform: "translateX(-50%)", letterSpacing: `${0.6 * fontUnit}px` }}>
                {data.hours[i][0]}
              </div>
            ) : null,
          )}
        </div>
      ) : null}
    </>
  );
};
