import React from "react";
import { AbsoluteFill, Img, random, staticFile, useCurrentFrame } from "remotion";
import { blue, dusk, night, white } from "./theme";

export type Layout = { W: number; H: number; wide: boolean };

/** The sky behind everything: the app's own night blue, lighter where the watch sits. */
export const Sky: React.FC<{ layout: Layout; glow?: number }> = ({ layout, glow = 1 }) => {
  const at = layout.wide ? "73% 52%" : "50% 60%";
  return (
    <AbsoluteFill
      style={{ background: `radial-gradient(ellipse 75% 60% at ${at}, ${mix(glow)} 0%, ${night} 100%)` }}
    />
  );
};

const mix = (glow: number) => {
  const channel = (a: number, b: number) => Math.round(a + (b - a) * glow);
  return `rgb(${channel(4, parseInt(dusk.slice(1, 3), 16))}, ${channel(7, parseInt(dusk.slice(3, 5), 16))}, ${channel(12, parseInt(dusk.slice(5, 7), 16))})`;
};

/**
 * Rain, drawn from fixed random numbers so every render is the same. `amount` from 0 to 1 is how
 * many streaks fall; `layer` 0 is far (small, slow, faint), 1 is near.
 */
export const Rain: React.FC<{ layout: Layout; amount: number; layer?: 0 | 1 }> = ({ layout, amount, layer = 0 }) => {
  const frame = useCurrentFrame();
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
        strokeOpacity={layer === 0 ? 0.16 + depth * 0.3 : 0.22}
        strokeWidth={layer === 0 ? 1.5 + depth * 2.2 : 3.2 * depth}
        strokeLinecap="round"
      />,
    );
  }
  return (
    <AbsoluteFill>
      <svg width={layout.W} height={layout.H}>
        {streaks}
      </svg>
    </AbsoluteFill>
  );
};

/** Apple's Ultra 3 frame is 600 x 960 with the 422 x 514 screen at (89, 223) (design/frame.py). */
export const frameSize = { w: 600, h: 960 };
export const screen = { x: 89, y: 223, w: 422, h: 514, radius: 104 };

/**
 * The watch, centred on (x, y) at `scale`. Children are drawn on the screen in its own 422 x 514
 * points, so a capture fills it exactly. `focus` moves a screen point to (x, y) instead of the
 * watch's middle, for close-ups.
 */
export const Watch: React.FC<{
  x: number;
  y: number;
  scale: number;
  focus?: { x: number; y: number };
  crown?: number;
  children: React.ReactNode;
}> = ({ x, y, scale, focus, crown = 0, children }) => {
  const frame = useCurrentFrame();
  const origin = focus
    ? { x: screen.x + focus.x, y: screen.y + focus.y }
    : { x: frameSize.w / 2, y: frameSize.h / 2 };
  const pulse = 0.75 + 0.25 * Math.sin(frame / 3.2);
  return (
    <div
      style={{
        position: "absolute",
        left: x - origin.x,
        top: y - origin.y,
        width: frameSize.w,
        height: frameSize.h,
        transform: `scale(${scale})`,
        transformOrigin: `${origin.x}px ${origin.y}px`,
        filter: "drop-shadow(0 40px 60px rgba(0,0,0,0.55))",
      }}
    >
      <div
        style={{
          position: "absolute",
          left: screen.x,
          top: screen.y,
          width: screen.w,
          height: screen.h,
          borderRadius: screen.radius,
          overflow: "hidden",
          background: "#000",
        }}
      >
        {children}
      </div>
      <Img src={staticFile("ultra-3-frame.png")} style={{ position: "absolute", inset: 0, width: frameSize.w, height: frameSize.h }} />
      {crown > 0 ? (
        <svg style={{ position: "absolute", left: 500, top: 290, overflow: "visible" }} width={160} height={190} opacity={crown}>
          <ellipse cx={73} cy={95} rx={30} ry={58} fill="none" stroke={blue} strokeWidth={5} opacity={pulse} />
          <ellipse cx={73} cy={95} rx={30 + 16 * pulse} ry={58 + 16 * pulse} fill="none" stroke={blue} strokeWidth={2} opacity={0.5 * (1 - pulse * 0.6)} />
          {[0, 1, 2, 3, 4, 5, 6].map((tick) => {
            const turn = (((frame * 2.4 + tick * 20) % 140) + 140) % 140;
            const fade = Math.sin((turn / 140) * Math.PI);
            return <line key={tick} x1={122} y1={25 + turn} x2={140} y2={25 + turn} stroke={white} strokeWidth={4} strokeLinecap="round" opacity={fade} />;
          })}
        </svg>
      ) : null}
    </div>
  );
};

/** A capture filling the screen. */
export const Shot: React.FC<{ src: string; opacity?: number }> = ({ src, opacity = 1 }) => (
  <Img src={staticFile(src)} style={{ position: "absolute", inset: 0, width: screen.w, height: screen.h, opacity }} />
);

/**
 * Dims the screen except the wide slot and the circle, to point at a complication without drawing
 * on it. `slot` and `circle` from 0 to 1 are how far each is let through.
 */
export const Spotlight: React.FC<{ slot: number; circle: number; strength: number }> = ({ slot, circle, strength }) => (
  <svg width={422} height={514} style={{ position: "absolute", inset: 0 }}>
    <mask id="spotlight">
      <rect width={422} height={514} fill="#fff" />
      <rect x={20} y={236} width={382} height={132} rx={14} fill="#000" fillOpacity={slot} />
      <circle cx={211} cy={428} r={50} fill="#000" fillOpacity={circle} />
    </mask>
    <rect width={422} height={514} fill="#000" fillOpacity={0.72 * strength} mask="url(#spotlight)" />
  </svg>
);
