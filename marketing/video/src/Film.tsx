import React from "react";
import { AbsoluteFill, Img, Sequence, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { copy, Lang } from "./copy";
import { bezel, Caption, captionBox, captionSize, Layout, Rain, Screen, Sky, Watch } from "./parts";
import { LineData, RainShape } from "./RainShape";
import { blue, cut, grey, inOut, night, ramp, type, white, yellow } from "./theme";
import map from "../public/gen/map.json";
import linesEn from "../public/gen/en/line.json";
import linesNl from "../public/gen/nl/line.json";

export type FilmProps = { lang: Lang; named: boolean };

const lines: Record<Lang, LineData[]> = { en: linesEn as LineData[], nl: linesNl as LineData[] };
/** The face minute the story starts from: "Dry for 10 min". */
const start = 1;
/** The face minute when the rain reaches the place (07:50 on the face). */
const rainArrives = 11;
/** The app's radar, captured in the simulator (README): 31 pictures, the present is the 7th. */
const radarShots = 31;

export const Film: React.FC<FilmProps> = ({ lang, named }) => {
  const frame = useCurrentFrame();
  const { width: W, height: H } = useVideoConfig();
  const layout: Layout = { W, H, wide: W > H };
  const words = copy[lang];
  const size = captionSize(layout);

  // Rain in the air: heavy for the hook, gone once the answer comes, back when it reaches the face.
  const faceMinute = faceIndex(frame - cut.face);
  const rain = frame < cut.answer ? 1 : frame < cut.radar ? ramp(frame, cut.answer, cut.answer + 30, 1, 0) :
    frame >= cut.face && frame < cut.stack && faceMinute >= rainArrives ? ramp(frame - cut.face, 102, 120, 0, 0.8) * (1 - ramp(frame, cut.stack - 12, cut.stack, 0, 1)) : 0;

  return (
    <AbsoluteFill style={{ backgroundColor: night, overflow: "hidden" }}>
      <Sky layout={layout} />
      <Rain layout={layout} amount={rain} layer={0} />
      <Sequence from={cut.hook} durationInFrames={cut.radar - cut.hook + 14}><Opening layout={layout} lang={lang} /></Sequence>
      <Sequence from={cut.radar} durationInFrames={cut.line - cut.radar + 14}><Radar layout={layout} lang={lang} /></Sequence>
      <Sequence from={cut.line} durationInFrames={cut.face - cut.line + 16}><LineToCircle layout={layout} lang={lang} /></Sequence>
      <Sequence from={cut.face} durationInFrames={cut.stack - cut.face}><Face layout={layout} lang={lang} /></Sequence>
      <Sequence from={cut.stack} durationInFrames={cut.compare - cut.stack}><Stack layout={layout} lang={lang} /></Sequence>
      <Sequence from={cut.compare} durationInFrames={cut.end - cut.compare}>
        {named ? <Compare layout={layout} lang={lang} /> : <TwoWays layout={layout} lang={lang} />}
      </Sequence>
      <Sequence from={cut.end}><End layout={layout} lang={lang} /></Sequence>
      {/* Near rain only while no watch is on screen: nothing may be drawn over Apple's product image. */}
      <Rain layout={layout} amount={frame < cut.answer ? 0.6 * (1 - ramp(frame, cut.answer - 12, cut.answer, 0, 1)) : 0} layer={1} />
      {/* Captions sit above the rain. */}
      <Sequence from={cut.radar} durationInFrames={cut.end - cut.radar}>
        <Captions layout={layout} lang={lang} size={size} />
      </Sequence>
    </AbsoluteFill>
  );
};

/** Which face minute is showing, `f` frames into the face shot: it holds on "Dry for 10 min", then runs. */
const faceIndex = (f: number) => Math.round(ramp(f, 80, 140, start, 27, (t) => t));

type Scene = { layout: Layout; lang: Lang };

/** Every caption from the radar on, at its time; each leaves before the next comes. */
const Captions: React.FC<Scene & { size: number }> = ({ layout, lang, size }) => {
  const words = copy[lang];
  const at = (shot: number) => shot - cut.radar;
  // Each comes in as the one before it leaves, so the screen never sits empty.
  const rows: [number, number, string][] = [
    [at(cut.radar) + 8, at(cut.line) + 2, words.radar],
    [at(cut.line) - 4, at(cut.line) + 76, words.line],
    [at(cut.line) + 70, at(cut.circle) + 2, words.height],
    [at(cut.circle) - 4, at(cut.circle) + 66, words.circle],
    [at(cut.circle) + 60, at(cut.face) + 2, words.minutes],
    [at(cut.face) - 4, at(cut.stack) + 2, words.decide],
    [at(cut.stack) - 4, at(cut.stack) + 66, words.stack],
    [at(cut.stack) + 60, at(cut.compare) + 2, words.radarApp],
  ];
  return (
    <div style={captionBox(layout)}>
      <div style={{ position: "relative" }}>
        {rows.map(([from, until, text]) => (
          <div key={text} style={{ position: layout.wide ? "relative" : "absolute", top: 0, left: 0, right: 0 }}>
            <Caption at={from} until={until} size={size}>{text}</Caption>
          </div>
        ))}
      </div>
    </div>
  );
};

// ---- 1. The hook, the chore, the answer ----

const Opening: React.FC<Scene> = ({ layout, lang }) => {
  const frame = useCurrentFrame();
  const words = copy[lang];
  const big = layout.wide ? 112 : 124;
  const box: React.CSSProperties = layout.wide
    ? { position: "absolute", left: 160, top: 0, width: 1400, height: layout.H, display: "flex", flexDirection: "column", justifyContent: "center" }
    : { position: "absolute", left: 84, top: 0, width: layout.W - 168, height: layout.H, display: "flex", flexDirection: "column", justifyContent: "center" };
  const answerAt = cut.answer - cut.hook;
  const choreAt = cut.chore - cut.hook;
  const name = words.answer.indexOf(words.name);
  // The product arrives with the answer: the watch, whole, with the caption above or beside it.
  const reveal = ramp(frame, answerAt, answerAt + 16) * (1 - ramp(frame, cut.radar - cut.hook - 8, cut.radar - cut.hook + 6, 0, 1));
  const pose = watchPose(layout);
  return (
    <>
      {reveal > 0 ? (
        <Watch x={pose.x} y={pose.y} height={pose.height} opacity={reveal}>
          <Screen src={`gen/${lang}/face/${String(start).padStart(2, "0")}.png`} />
        </Watch>
      ) : null}
      <div style={box}>
        <div style={{ position: "relative" }}>
          <Caption at={0} until={choreAt + 4} size={big}>{words.hook}</Caption>
          <div style={{ position: "absolute", top: 0 }}><Caption at={choreAt - 4} until={answerAt + 4} size={big * 0.82}>{words.chore}</Caption></div>
        </div>
      </div>
      <div style={captionBox(layout)}>
        <Caption at={answerAt - 4} until={cut.radar - cut.hook + 6} size={captionSize(layout)}>
          {name >= 0 ? (
            <>
              {words.answer.slice(0, name)}<span style={{ color: blue }}>{words.name}</span>{words.answer.slice(name + words.name.length)}
            </>
          ) : words.answer}
        </Caption>
      </div>
    </>
  );
};

// ---- 2. KNMI's radar, closing in on one square kilometre ----

/** Where the map's subject sits: below the captions when tall, right of them when wide. */
const stage = (layout: Layout) => (layout.wide ? { x: 1340, y: 560, w: 1000, h: 980 } : { x: 540, y: 1180, w: 1000, h: 1300 });

const Radar: React.FC<Scene> = ({ layout }) => {
  const frame = useCurrentFrame();
  const s = stage(layout);
  const fit = Math.min(s.w / map.width, s.h / map.height);
  // From the whole country to one cell 90 pixels across, at a steady rate of zoom.
  const reach = map.reach, across = 2 * reach + 1;
  const closest = (layout.wide ? 64 : 90) / (3 * fit);
  const zoom = Math.exp(Math.log(closest) * ramp(frame, 30, 112, 0, 1, inOut));
  const scale = fit * zoom;
  const toward = ramp(frame, 30, 112, 0, 1, inOut);
  const placeX = s.x + (map.place.x - map.width / 2) * fit * (1 - toward);
  const placeY = s.y + (map.place.y - map.height / 2) * fit * (1 - toward);
  // The radar runs from 30 minutes ago to now (07:40 on the face), then, close up, on to 07:55,
  // when the rain has reached the place.
  const step = frame < 84 ? Math.round(ramp(frame, 0, 70, 0, 8, (t) => t)) : Math.round(ramp(frame, 90, 128, 8, 11, (t) => t));
  const leave = ramp(frame, cut.line - cut.radar - 2, cut.line - cut.radar + 12, 1, 0);
  const clock = new Date(Date.UTC(2026, 0, 1, 7, 30 + (step - 6) * 5));
  const cell = 3 * scale;
  // Close up, the smooth picture gives way to KNMI's own cells.
  const cells = ramp(zoom, 4, 9, 0, 1, (t) => t);
  const fade = `radial-gradient(ellipse ${layout.wide ? "48% 50%" : "60% 46%"} at ${(s.x / layout.W) * 100}% ${(s.y / layout.H) * 100}%, #000 62%, transparent 100%)`;
  return (
    <AbsoluteFill style={{ opacity: ramp(frame, 0, 14) * leave }}>
      <AbsoluteFill style={{ maskImage: fade, WebkitMaskImage: fade }}>
        <div style={{ position: "absolute", left: placeX - map.place.x * scale, top: placeY - map.place.y * scale, width: map.width, height: map.height, transform: `scale(${scale})`, transformOrigin: "0 0", opacity: 1 - cells }}>
          <Img src={staticFile(`gen/radar/${String(step).padStart(2, "0")}.png`)} style={{ position: "absolute", inset: 0, width: map.width, height: map.height }} />
          <svg width={map.width} height={map.height} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            {[map.coast, map.lakes].map((d, i) => (
              <path key={i} d={d} fill="none" stroke="#9AA6B8" strokeOpacity={0.75} strokeWidth={1.9 / scale} strokeLinejoin="round" />
            ))}
            <path d={map.borders} fill="none" stroke="#9AA6B8" strokeOpacity={0.45} strokeWidth={1.4 / scale} strokeDasharray={`${5 / scale} ${5 / scale}`} />
          </svg>
        </div>
        {cells > 0 ? (
          <div style={{ position: "absolute", left: placeX - (across * cell) / 2, top: placeY - (across * cell) / 2, width: across * cell, height: across * cell, opacity: cells }}>
            {map.cells[step].map((row: number[], r: number) =>
              row.map((byte: number, c: number) => (
                <div key={`${r}-${c}`} style={{ position: "absolute", left: c * cell + 1, top: r * cell + 1, width: cell - 2, height: cell - 2, borderRadius: cell * 0.08,
                  background: byte === 0 ? "rgba(255,255,255,0.04)" : cellColour(byte) }} />
              )),
            )}
          </div>
        ) : null}
      </AbsoluteFill>
      {/* The place's own square kilometre. */}
      <div style={{ position: "absolute", left: placeX - cell / 2 - 3, top: placeY - cell / 2 - 3, width: cell + 6, height: cell + 6, border: `4px solid ${white}`, borderRadius: cell * 0.12, opacity: cells }} />
      <div style={{ position: "absolute", left: placeX - 11, top: placeY - 11, width: 22, height: 22, borderRadius: 11, background: yellow, boxShadow: "0 0 0 3px rgba(0,0,0,0.6)", opacity: ramp(frame, 20, 30) }} />
      <div style={{ ...type(32, 600), position: "absolute", left: placeX + 26, top: placeY - 20, opacity: ramp(frame, 24, 36) * (1 - cells), whiteSpace: "nowrap", textShadow: "0 1px 6px rgba(0,0,0,0.8)" }}>{map.place.name}</div>
      <div style={{ ...type(30, 500), color: grey, position: "absolute", left: layout.wide ? s.x - s.w / 2 + 60 : 84, top: layout.wide ? s.y + s.h / 2 - 40 : s.y + s.h / 2 - 50, fontVariantNumeric: "tabular-nums" }}>
        KNMI {clock.toISOString().slice(11, 16)}
      </div>
    </AbsoluteFill>
  );
};

/** The app's radar colour for one of KNMI's bytes (RadarPage.swift, Painter.colour), close up. */
const cellColour = (byte: number) => {
  if (byte === 255) return "rgba(140,140,153,0.4)";
  const smooth = (a: number, b: number, x: number) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  const mix = (a: number[], b: number[], t: number) => a.map((v, i) => v + (b[i] - v) * t);
  const [blueC, light, whiteC, red] = [[0.35, 0.61, 0.83], [0.62, 0.82, 1], [0.93, 0.97, 1], [1, 0.3, 0.3]];
  const [rgb, alpha] = byte < 51 ? [mix(blueC, light, smooth(1, 51, byte)), 0.5 + 0.25 * smooth(1, 51, byte)]
    : byte < 86 ? [mix(light, whiteC, smooth(51, 86, byte)), 0.75 + 0.2 * smooth(51, 86, byte)]
    : [mix(whiteC, red, smooth(91, 101, byte)), 0.95 + 0.05 * smooth(91, 101, byte)];
  return `rgba(${rgb.map((v) => Math.round(v * 255)).join(",")},${alpha})`;
};

// ---- 3. The square's next two hours as the app's line, bent into the circle, turned ----

const LineToCircle: React.FC<Scene> = ({ layout, lang }) => {
  const frame = useCurrentFrame();
  const data = lines[lang][start];
  const s = stage(layout);
  const chart = layout.wide ? { x: s.x - 420, y: s.y + 230, w: 840, h: 420 } : { x: 84, y: s.y + 330, w: layout.W - 168, h: 560 };
  const d = layout.wide ? 640 : 820;
  const circle = { x: s.x, y: s.y + (layout.wide ? 0 : 40), d };
  const circleAt = cut.circle - cut.line;
  const bend = ramp(frame, circleAt, circleAt + 26, 0, 1, inOut);
  const real = ramp(frame, circleAt + 26, circleAt + 34);
  // The circle turns to show another real forecast: rain now, for 15 more minutes.
  const turns = [circleAt + 84];
  const states = ["onAndOff"];
  let shown = "start", angle = 0;
  turns.forEach((t, i) => {
    if (frame >= t) shown = states[i];
    if (frame >= t - 9 && frame < t) angle = ramp(frame, t - 9, t, 0, 90, inOut);
    if (frame >= t && frame < t + 9) angle = ramp(frame, t, t + 9, -90, 0, inOut);
  });
  const leave = ramp(frame, cut.face - cut.line, cut.face - cut.line + 14, 1, 0);
  return (
    <AbsoluteFill style={{ opacity: leave }}>
      {frame < 20 ? (
        <div style={{ position: "absolute", border: `4px solid ${white}`, borderRadius: 10,
          left: s.x + (chart.x - s.x) * ramp(frame, 0, 18, 0, 1, inOut) - 48 * (1 - ramp(frame, 0, 18, 0, 1, inOut)),
          top: s.y + (chart.y - s.y) * ramp(frame, 0, 18, 0, 1, inOut) - 48 * (1 - ramp(frame, 0, 18, 0, 1, inOut)),
          width: 96 * (1 - ramp(frame, 0, 18, 0, 1, inOut)), height: 96 * (1 - ramp(frame, 0, 18, 0, 1, inOut)), opacity: 1 - ramp(frame, 14, 20) }} />
      ) : null}
      {real < 1 ? (
        <div style={{ position: "absolute", inset: 0, opacity: 1 - real, perspective: 1600, perspectiveOrigin: `${chart.x + chart.w / 2}px ${chart.y - chart.h / 2}px` }}>
         <div style={{ position: "absolute", inset: 0, transformOrigin: `${chart.x + chart.w / 2}px ${chart.y}px`,
           transform: `rotateX(${ramp(frame, 4, 52, 34, 0, inOut)}deg) rotateY(${ramp(frame, 4, 52, -16, 0, inOut)}deg)` }}>
          {/* The circle's grey disc grows under the bending line. */}
          <div style={{ position: "absolute", left: circle.x - d / 2, top: circle.y - d / 2, width: d, height: d, borderRadius: d, background: "rgba(255,255,255,0.13)", opacity: bend, transform: `scale(${0.6 + 0.4 * bend})` }} />
          <RainShape data={data} chart={chart} circle={circle} bend={bend} draw={ramp(frame, 6, 44, 0, 1, inOut)} labels={ramp(frame, 30, 44) * (1 - ramp(frame, circleAt, circleAt + 10))} grid={ramp(frame, 56, 70) * (1 - ramp(frame, circleAt, circleAt + 10))} />
         </div>
        </div>
      ) : null}
      {real > 0 ? (
        <div style={{ position: "absolute", left: circle.x - d / 2, top: circle.y - d / 2, width: d, height: d, perspective: 2400, opacity: real }}>
          <Img src={staticFile(`gen/${lang}/circle/${shown === "start" ? String(start).padStart(2, "0") : shown}.png`)}
            style={{ width: d, height: d, transform: `rotateY(${angle}deg)` }} />
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

// ---- 4. On the watch: the face counts down to the rain ----

const watchPose = (layout: Layout) => (layout.wide ? { x: 1340, y: 512, height: 920 } : { x: 540, y: 1196, height: 1220 });

const Face: React.FC<Scene> = ({ layout, lang }) => {
  const frame = useCurrentFrame();
  const words = copy[lang];
  const pose = watchPose(layout);
  const index = faceIndex(frame);
  const length = cut.stack - cut.face;
  const leave = ramp(frame, length - 14, length, 1, 0);
  // The whole watch first, then in to its two complications (Apple allows a push-in after an
  // establishing shot of the whole device), and back out before it goes.
  const push = ramp(frame, 34, 74, 0, 1, inOut) * (1 - ramp(frame, length - 34, length - 8, 0, 1, inOut));
  // Never under the words: Apple allows copy beside the product image, not on top of it. Tall, the
  // watch grows to the frame's width with its top just below the caption; wide, it stays right of it.
  const zoom = layout.wide ? 1.6 : 1.34;
  const focus = layout.wide ? { x: bezel.w / 2, y: 470 } : { x: bezel.w / 2, y: 0 };
  const to = layout.wide ? { x: 1400, y: 540 } : { x: 540, y: 392 };
  return (
    <AbsoluteFill>
      <Watch x={pose.x} y={pose.y} height={pose.height} opacity={ramp(frame, 0, 16) * leave} zoom={zoom} focus={focus} to={to} push={push}>
        <Screen src={`gen/${lang}/face/${String(index).padStart(2, "0")}.png`} />
      </Watch>
      <div style={{ ...type(28, 500), color: grey, position: "absolute", left: layout.wide ? 120 : 84, top: layout.wide ? layout.H / 2 + 110 : 346, opacity: ramp(frame, 76, 88) * leave }}>
        {words.shortened}
      </div>
    </AbsoluteFill>
  );
};

// ---- 5. The Smart Stack card, then the radar in the app ----

const Stack: React.FC<Scene> = ({ layout, lang }) => {
  const frame = useCurrentFrame();
  const pose = watchPose(layout);
  const s = stage(layout);
  const cardW = layout.wide ? 900 : 960;
  const cardH = (cardW * 81.5) / 198;
  const turn = ramp(frame, 4, 34, 1, 0, inOut);
  const cardOut = ramp(frame, 44, 56, 1, 0, inOut);
  const radarIn = ramp(frame, 50, 64);
  const step = Math.round(ramp(frame, 64, cut.compare - cut.stack - 6, 6, radarShots - 1, (t) => t));
  const leave = ramp(frame, cut.compare - cut.stack - 12, cut.compare - cut.stack, 1, 0);
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", left: s.x - cardW / 2, top: s.y - cardH / 2, width: cardW, height: cardH, perspective: 1800, opacity: ramp(frame, 0, 10) * cardOut }}>
        <Img src={staticFile(`gen/${lang}/stack/${String(start).padStart(2, "0")}.png`)}
          style={{ width: cardW, height: cardH, transform: `rotateX(${turn * 38}deg) rotateZ(${turn * -6}deg) scale(${1 - turn * 0.18}) translateY(${turn * 120}px)` }} />
      </div>
      {radarIn > 0 ? (
        <Watch x={pose.x} y={pose.y} height={pose.height} opacity={radarIn * leave}>
          <Screen src={`radar/${lang}/${String(step).padStart(2, "0")}.png`} />
        </Watch>
      ) : null}
    </AbsoluteFill>
  );
};

// ---- 6. The comparison: what each app puts in the same slot of the watch face ----

/** One wide slot of the face, drawn large: RainWatch's real view, live, or what another app shows there. */
const Slot: React.FC<{ w: number; at: number; lang: Lang; live?: boolean; text?: string; ours?: boolean }> = ({ w, at, lang, live, text, ours }) => {
  const frame = useCurrentFrame();
  const h = (w * 73.5) / 190;
  const minute = Math.round(ramp(frame, at, at + 170, start, 24, (t) => t));
  return (
    <div style={{ position: "relative", width: w, height: h + 0.12 * w, borderRadius: 0.07 * w, background: "#000",
      border: `${ours ? 3 : 2}px solid ${ours ? blue : "rgba(255,255,255,0.16)"}`, overflow: "hidden" }}>
      {live ? (
        <Img src={staticFile(`gen/${lang}/wide/${String(minute).padStart(2, "0")}.png`)} style={{ position: "absolute", left: 0.06 * w, top: 0.06 * w, width: w * 0.88, height: h * 0.88 }} />
      ) : (
        <div style={{ ...type(0.06 * w, 500), color: grey, position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", textAlign: "center", padding: 0.08 * w }}>{text}</div>
      )}
    </div>
  );
};

const Compare: React.FC<Scene> = ({ layout, lang }) => {
  const frame = useCurrentFrame();
  const words = copy[lang];
  const wide = layout.wide;
  const slotW = wide ? 520 : 760;
  const enter = (at: number) => ({ opacity: ramp(frame, at, at + 16), transform: `translateY(${(1 - ramp(frame, at, at + 16)) * 60}px)` });
  const length = cut.end - cut.compare;
  return (
    <AbsoluteFill style={{ opacity: ramp(frame, 0, 8) * ramp(frame, length - 8, length, 1, 0) }}>
      <div style={{ position: "absolute", left: wide ? 120 : 84, right: wide ? 120 : 84, top: wide ? 0 : 160, bottom: wide ? 90 : 150, display: "flex", flexDirection: "column", justifyContent: "center" }}>
        <div style={{ ...type(wide ? 72 : 80), marginBottom: wide ? 56 : 64, ...enter(2) }}>{words.compareTitle}</div>
        <div style={{ display: "flex", flexDirection: wide ? "row" : "column", gap: wide ? 60 : 54 }}>
          {words.rows.map((row, i) => {
            const at = 16 + i * 26;
            return (
              <div key={row.name} style={{ display: "flex", flexDirection: "column", gap: 18, ...enter(at) }}>
                <div style={{ ...type(wide ? 44 : 50), color: i === 0 ? white : "#C9D1DC" }}>{row.name}</div>
                <Slot w={slotW} at={at} lang={lang} live={i === 0} ours={i === 0} text={row.note} />
              </div>
            );
          })}
        </div>
      </div>
      <div style={{ ...type(wide ? 26 : 28, 400), color: grey, position: "absolute", left: wide ? 140 : 84, right: 84, bottom: wide ? 44 : 90, ...enter(90) }}>{words.sources}</div>
    </AbsoluteFill>
  );
};

const TwoWays: React.FC<Scene> = ({ layout, lang }) => {
  const frame = useCurrentFrame();
  const words = copy[lang];
  const wide = layout.wide;
  const slotW = wide ? 620 : 760;
  const enter = (at: number) => ({ opacity: ramp(frame, at, at + 16), transform: `translateY(${(1 - ramp(frame, at, at + 16)) * 60}px)` });
  const length = cut.end - cut.compare;
  return (
    <AbsoluteFill style={{ opacity: ramp(frame, 0, 8) * ramp(frame, length - 8, length, 1, 0) }}>
      <div style={{ position: "absolute", left: wide ? 120 : 84, right: wide ? 120 : 84, top: wide ? 0 : 160, bottom: 60, display: "flex", flexDirection: "column", justifyContent: "center" }}>
        <div style={{ ...type(wide ? 72 : 80), marginBottom: wide ? 56 : 64, ...enter(2) }}>{words.unnamedTitle}</div>
        <div style={{ display: "flex", flexDirection: wide ? "row" : "column", gap: wide ? 90 : 60 }}>
          {words.unnamed.map((row, i) => {
            const at = 20 + i * 40;
            return (
              <div key={row.name} style={{ display: "flex", flexDirection: "column", gap: 18, ...enter(at) }}>
                <div style={{ ...type(wide ? 44 : 50), color: i === 1 ? white : "#C9D1DC" }}>{row.name}</div>
                {i === 1 ? <Slot w={slotW} at={at} lang={lang} live ours /> : null}
                <div style={{ ...type(wide ? 40 : 44, 600), color: i === 1 ? blue : grey }}>{row.note}</div>
              </div>
            );
          })}
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ---- 7. The name and where to get it ----

/** Shown still, all at once: Apple's badge may not be animated, so nothing round it is either. */
const End: React.FC<Scene> = ({ layout, lang }) => {
  const words = copy[lang];
  const wide = layout.wide;
  const k = wide ? 0.9 : 1;
  // A quarter of the badge's height kept clear round it.
  const badgeH = wide ? 96 : 110;
  const text = (
    <>
      <div style={{ display: "flex", alignItems: "center", gap: 32 * k }}>
        <Img src={staticFile("icon.png")} style={{ width: 150 * k, height: 150 * k, borderRadius: "50%" }} />
        <div style={{ ...type(140 * k, 800) }}>{words.name}</div>
      </div>
      <div style={{ ...type(58 * k, 600), color: blue, marginTop: 18 * k, whiteSpace: "nowrap" }}>{words.endFor}</div>
      <div style={{ ...type(50 * k, 600), marginTop: 30 * k, maxWidth: wide ? 900 : 912 }}>{words.endPromise}</div>
      <div style={{ marginTop: 44 * k, padding: badgeH / 4, marginLeft: -badgeH / 4 }}>
        <Img src={staticFile(`badge/${lang}.svg`)} style={{ height: badgeH, display: "block" }} />
      </div>
    </>
  );
  return (
    <AbsoluteFill>
      {wide ? (
        <>
          <div style={{ position: "absolute", left: 140, top: 0, height: layout.H - 60, display: "flex", flexDirection: "column", justifyContent: "center" }}>{text}</div>
          <Watch x={1440} y={500} height={860}><Screen src={`gen/${lang}/face/27.png`} /></Watch>
        </>
      ) : (
        <>
          <Watch x={540} y={560} height={900}><Screen src={`gen/${lang}/face/27.png`} /></Watch>
          <div style={{ position: "absolute", left: 84, top: 1080 }}>{text}</div>
        </>
      )}
      <div style={{ ...type(wide ? 20 : 22, 400), color: grey, position: "absolute", left: wide ? 140 : 84, width: wide ? 1000 : 912, bottom: wide ? 36 : 70 }}>{words.credit}</div>
    </AbsoluteFill>
  );
};
