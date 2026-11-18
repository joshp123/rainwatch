import { Easing, interpolate } from "remotion";

/** One accent, as in the app (DESIGN.md rule 2): blue is rain, white is a value, grey is secondary. */
export const blue = "#5A9BD3";
export const white = "#F4F7FB";
export const grey = "#8B96A8";
export const night = "#04070C";
export const dusk = "#0F2036";

export const fps = 30;

/** The shots, in frames. One place to retime the film. */
export const cut = {
  hook: 0,
  pain: 72,
  hero: 168,
  places: 396,
  radar: 516,
  rivals: 660,
  end: 756,
  total: 846,
};

export const out = Easing.bezier(0.16, 1, 0.3, 1);
export const inOut = Easing.bezier(0.65, 0, 0.35, 1);

export const ramp = (frame: number, from: number, to: number, a = 0, b = 1, easing = out) =>
  interpolate(frame, [from, to], [a, b], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing });

export const type = (size: number, weight = 800, width = 100): React.CSSProperties => ({
  fontFamily: "Archivo",
  fontSize: size,
  lineHeight: 1.02,
  fontVariationSettings: `"wght" ${weight}, "wdth" ${width}`,
  letterSpacing: "-0.02em",
  color: white,
});
