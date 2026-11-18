import { Easing, interpolate } from "remotion";

/** The app's colours (RainPalette): one accent, Buienradar blue for rain; white is a value, grey secondary. */
export const blue = "#5A9BD3";
export const white = "#F4F7FB";
export const grey = "#8B96A8";
export const night = "#04070C";
export const yellow = "#FFD60A";

export const fps = 30;

/** Where each shot starts, in frames. One place to retime the film. */
export const cut = {
  hook: 0,
  chore: 66,
  answer: 138,
  radar: 234,
  line: 360,
  circle: 516,
  face: 660,
  stack: 840,
  compare: 1008,
  end: 1236,
  total: 1368,
};

export const out = Easing.bezier(0.16, 1, 0.3, 1);
export const inOut = Easing.bezier(0.65, 0, 0.35, 1);

export const ramp = (frame: number, from: number, to: number, a = 0, b = 1, easing = out) =>
  interpolate(frame, [from, to], [a, b], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing });

/** The film's own words: Inter (SIL Open Font Licence). */
export const type = (size: number, weight = 700): React.CSSProperties => ({
  fontFamily: "Inter",
  fontSize: size,
  fontWeight: weight,
  lineHeight: 1.12,
  letterSpacing: size > 40 ? "-0.025em" : "-0.005em",
  color: white,
});

/** The app's words, in the watch's own face font. */
export const appType = (size: number, weight = 600): React.CSSProperties => ({
  fontFamily: "SF Compact Rounded",
  fontSize: size,
  fontWeight: weight,
  lineHeight: 1.1,
  color: white,
});
