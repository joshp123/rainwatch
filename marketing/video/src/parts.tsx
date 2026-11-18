import React from "react";
import { AbsoluteFill, Img, random, staticFile, useCurrentFrame } from "remotion";
import { blue, night, ramp, type, white } from "./theme";

export type Layout = { W: number; H: number; wide: boolean };

/** The film's background: the app's night, a little lighter where the subject sits. */
export const Sky: React.FC<{ layout: Layout }> = ({ layout }) => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(ellipse 80% 65% at ${layout.wide ? "70% 55%" : "50% 62%"}, #0D1A2C 0%, ${night} 100%)`,
    }}
  />
);

/**
 * Rain, drawn from fixed random numbers so every render is the same. `amount` from 0 to 1 is how
 * many streaks fall; `layer` 0 is far (small, slow, faint), 1 is near.
 */
export const Rain: React.FC<{ layout: Layout; amount: number; layer?: 0 | 1 }> = ({ layout, amount, layer = 0 }) => {
  const frame = useCurrentFrame();
  if (amount <= 0) return null;
  const count = layer === 0 ? 150 : 46;
  const slant = 0.2;
  const streaks = [];
  for (let i = 0; i < count; i++) {
    if (random(`show-${layer}-${i}`) > amount) continue;
    const depth = layer === 0 ? 0.35 + random(`depth-${i}`) * 0.4 : 0.85 + random(`near-${i}`) * 0.5;
    const speed = 38 * depth + 14;
    const length = 150 * depth;
    const lap = layout.H + length * 2;
    const y = ((random(`y-${layer}-${i}`) * lap + frame * speed) % lap) - length;
    const x = random(`x-${layer}-${i}`) * (layout.W + layout.H * slant) - y * slant;
    streaks.push(
      <line
        key={i}
        x1={x}
        y1={y}
        x2={x - length * slant}
        y2={y + length}
        stroke={layer === 0 ? blue : white}
        strokeOpacity={layer === 0 ? 0.16 + depth * 0.3 : 0.2}
        strokeWidth={layer === 0 ? 1.5 + depth * 2.2 : 3.2 * depth}
        strokeLinecap="round"
      />,
    );
  }
  return (
    <AbsoluteFill>
      <svg width={layout.W} height={layout.H}>{streaks}</svg>
    </AbsoluteFill>
  );
};

/**
 * Apple's Apple Watch Ultra 4 bezel (Apple Design Resources), natural titanium with the grey Ocean
 * Band: 620 x 940, its screen 422 x 514 at (98.5, 212.5) in a see-through opening. Apple's rules
 * for product images: shown whole, upright and unaltered; it may be placed and scaled, and it fades
 * in and out, nothing more.
 */
export const bezel = { w: 620, h: 940, screen: { x: 98.5, y: 212.5, w: 422, h: 514 }, hole: { x: 81, y: 194, w: 458, h: 552 } };

export const Watch: React.FC<{
  x: number; y: number; height: number; opacity?: number;
  /** Push in: `zoom` times larger, the bezel point `focus` moving to `to`. Only after the whole watch has been shown. */
  zoom?: number; focus?: { x: number; y: number }; to?: { x: number; y: number }; push?: number;
  children: React.ReactNode;
}> = ({ x, y, height, opacity = 1, zoom = 1, focus, to, push = 0, children }) => {
  const base = height / bezel.h;
  const left0 = x - (bezel.w * base) / 2, top0 = y - height / 2;
  const f = focus ?? { x: bezel.w / 2, y: bezel.h / 2 };
  const target = to ?? { x: left0 + f.x * base, y: top0 + f.y * base };
  const s = base * (1 + (zoom - 1) * push);
  const px = left0 + f.x * base + (target.x - (left0 + f.x * base)) * push;
  const py = top0 + f.y * base + (target.y - (top0 + f.y * base)) * push;
  return (
    <div style={{ position: "absolute", left: px - f.x * s, top: py - f.y * s, width: bezel.w, height: bezel.h, transform: `scale(${s})`, transformOrigin: "0 0", opacity }}>
      <div style={{ position: "absolute", left: bezel.hole.x, top: bezel.hole.y, width: bezel.hole.w, height: bezel.hole.h, borderRadius: 120, background: "#000" }} />
      <div style={{ position: "absolute", left: bezel.screen.x, top: bezel.screen.y, width: bezel.screen.w, height: bezel.screen.h, borderRadius: 100, overflow: "hidden", background: "#000" }}>
        {children}
      </div>
      <Img src={staticFile("bezel.png")} style={{ position: "absolute", inset: 0, width: bezel.w, height: bezel.h }} />
    </div>
  );
};

/** A picture filling the watch's screen. */
export const Screen: React.FC<{ src: string; opacity?: number }> = ({ src, opacity = 1 }) => (
  <Img src={staticFile(src)} style={{ position: "absolute", inset: 0, width: bezel.screen.w, height: bezel.screen.h, opacity }} />
);

/** Where captions sit: above the subject when tall, to its left when wide. */
export const captionBox = (layout: Layout): React.CSSProperties =>
  layout.wide
    ? { position: "absolute", left: 120, top: 0, width: 760, height: layout.H, display: "flex", flexDirection: "column", justifyContent: "center" }
    : { position: "absolute", left: 84, top: 170, width: layout.W - 168 };

export const captionSize = (layout: Layout) => (layout.wide ? 64 : 72);

/** A caption that rises into place at `at` and leaves at `until`. */
export const Caption: React.FC<{ at: number; until?: number; size: number; colour?: string; weight?: number; children: React.ReactNode }> = ({
  at, until, size, colour = white, weight = 700, children,
}) => {
  const frame = useCurrentFrame();
  if (frame < at || (until !== undefined && frame >= until)) return null;
  const enter = ramp(frame, at, at + 16);
  const leave = until === undefined ? 0 : ramp(frame, until - 10, until, 0, 1);
  return (
    <div
      style={{
        ...type(size, weight),
        color: colour,
        opacity: enter * (1 - leave),
        transform: `translateY(${(1 - enter) * size * 0.5 - leave * size * 0.25}px)`,
        filter: `blur(${(1 - enter) * 6}px)`,
      }}
    >
      {children}
    </div>
  );
};
