import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { copy, Lang } from "./copy";
import captures from "./captures.json";
import { Layout, Rain, Shot, Sky, Spotlight, Watch } from "./parts";
import { blue, cut, grey, inOut, night, ramp, type, white } from "./theme";

export type FilmProps = { lang: Lang; named: boolean };

/** A line of type that rises into place, wide to normal, and can leave again. */
const Line: React.FC<{
  at: number;
  until?: number;
  size: number;
  weight?: number;
  colour?: string;
  dim?: number;
  children: React.ReactNode;
}> = ({ at, until, size, weight = 850, colour = white, dim = 1, children }) => {
  const frame = useCurrentFrame();
  const enter = ramp(frame, at, at + 14);
  const leave = until === undefined ? 0 : ramp(frame, until - 8, until, 0, 1, inOut);
  if (frame < at || (until !== undefined && frame >= until)) return <div style={{ ...type(size, weight), visibility: "hidden" }}>{children}</div>;
  return (
    <div
      style={{
        ...type(size, weight, 112 - 12 * enter),
        color: colour,
        opacity: enter * (1 - leave) * dim,
        transform: `translateY(${(1 - enter) * size * 0.45 - leave * size * 0.3}px)`,
        whiteSpace: "nowrap",
      }}
    >
      {children}
    </div>
  );
};

export const Film: React.FC<FilmProps> = ({ lang, named }) => {
  const frame = useCurrentFrame();
  const { width: W, height: H } = useVideoConfig();
  const layout: Layout = { W, H, wide: W > H };
  const words = copy[lang];
  const shots = captures[lang];
  const k = layout.wide ? 0.9 : 1;

  // Where the words sit: beside the watch when wide, above it when tall.
  const beside: React.CSSProperties = layout.wide
    ? { position: "absolute", left: 130, top: 0, width: 860, height: H, display: "flex", flexDirection: "column", justifyContent: "center" }
    : { position: "absolute", left: 84, top: 210, width: W - 168 };
  const alone: React.CSSProperties = layout.wide
    ? { position: "absolute", left: (W - 1080) / 2, top: 0, width: 1080, height: H, display: "flex", flexDirection: "column", justifyContent: "center" }
    : { position: "absolute", left: 84, top: 0, width: W - 168, height: H, display: "flex", flexDirection: "column", justifyContent: "center" };

  // --- The forecast as it was on the face at this moment of the time-lapse.
  const hero = frame - cut.hero;
  const lapse = ramp(hero, 62, 192, 0, 1, (t) => t);
  const moment = shots.lapseFrom + (shots.lapseTo - shots.lapseFrom) * lapse;
  const face = [...shots.face].reverse().find((state) => state.t <= moment) ?? shots.face[0];
  const raining = moment >= shots.rainAt;

  // --- Rain in the air follows the story: wet, dry on the wrist, then the shower the watch foretold.
  const sinceRain = hero - (62 + ((shots.rainAt - shots.lapseFrom) / (shots.lapseTo - shots.lapseFrom)) * 130);
  const far =
    frame < cut.pain ? 1
    : frame < cut.hero ? 0.75
    : !raining ? ramp(hero, 0, 24, 0.75, 0)
    : frame < cut.rivals ? ramp(sinceRain, 0, 30, 0, 0.9)
    : frame < cut.end ? ramp(frame, cut.rivals, cut.rivals + 20, 0.9, 0.45)
    : 0.35;
  const near = frame < cut.pain ? ramp(frame, 56, 72, 1, 0.3) : raining && frame < cut.rivals ? ramp(sinceRain, 6, 40, 0, 0.5) * ramp(frame, cut.radar, cut.radar + 20, 1, 0.35) : 0;

  // --- The watch: rises, drifts closer while time passes, leans in on the widgets, steps back for the radar.
  const places = frame - cut.places;
  const radar = frame - cut.radar;
  const back = 1 - ramp(radar, 0, 26, 0, 1, inOut);
  const lean = ramp(hero, 56, 112, 0, 1, inOut) * back;
  const close = ramp(places, 0, 28, 0, 1, inOut) * back;
  const base = layout.wide ? { x: 1410, y: 556, scale: 1.02, focus: 257 } : { x: 540, y: 1170, scale: 1.4, focus: 257 };
  const mid = layout.wide ? { x: 1440, y: 560, scale: 1.34, focus: 290 } : { x: 540, y: 1250, scale: 1.86, focus: 300 };
  const tight = layout.wide ? { x: 1480, y: 560, scale: 1.72, focus: 352 } : { x: 540, y: 1290, scale: 2.2, focus: 352 };
  const between = (key: "x" | "y" | "scale" | "focus") => {
    const leaned = base[key] + (mid[key] - base[key]) * lean;
    return leaned + (tight[key] - leaned) * close;
  };
  const rise = (1 - ramp(hero, 4, 36)) * H * 0.9 + ramp(frame, cut.rivals - 14, cut.rivals + 4, 0, 1, inOut) * H * 1.1;
  const pose = {
    x: between("x"),
    y: between("y") + rise,
    scale: between("scale") + ramp(radar, 0, 26, 0, layout.wide ? 0.04 : 0.1, inOut),
    focus: { x: 211, y: between("focus") },
  };

  // --- What is on the watch's screen.
  const page = ramp(radar, 6, 16, 0, 1, inOut);
  const map = ramp(radar, 42, 52, 0, 1, inOut);
  const step = Math.round(ramp(radar, 58, 132, shots.radarNow, shots.radar - 1, (t) => t));
  const dim = ramp(places, 14, 24) * (1 - ramp(places, 112, 122));
  const slotLit = 1 - ramp(places, 42, 52, 0, 1, inOut) + ramp(places, 78, 88, 0, 1, inOut);
  const circleLit = ramp(places, 42, 52, 0, 1, inOut);

  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      <Sky layout={layout} glow={frame < cut.hero ? 0.55 : frame < cut.rivals ? 1 : 0.7} />
      <Rain layout={layout} amount={far} layer={0} />

      {/* 1. The hook: legible on the very first frame, for a muted feed. */}
      {frame < cut.pain ? (
        <div style={{ ...alone, opacity: 1 - ramp(frame, 58, 72, 0, 1, inOut), transform: `translateY(${ramp(frame, 58, 72, 0, 140, inOut)}px) scale(${1.07 - 0.07 * ramp(frame, 0, 16)})`, transformOrigin: "left center", filter: `blur(${ramp(frame, 58, 72, 0, 14)}px)` }}>
          <div style={{ ...type(212 * k, 900, 108 - 6 * ramp(frame, 0, 16)) }}>{words.hook[0]}</div>
          <div style={{ ...type(212 * k, 900, 108 - 6 * ramp(frame, 0, 16)), color: blue }}>{words.hook[1]}</div>
        </div>
      ) : null}

      {/* 2. The chore, one step at a time, then struck out. */}
      {frame >= cut.pain && frame < cut.hero + 12 ? (
        <div style={alone}>
          <div style={{ opacity: 1 - ramp(frame, cut.pain + 60, cut.pain + 68, 0, 1, inOut), display: "flex", flexDirection: "column", gap: 34 * k }}>
            {words.pain.map((line, index) => {
              const at = cut.pain + index * 16;
              const strike = ramp(frame, cut.pain + 50 + index * 3, cut.pain + 58 + index * 3, 0, 1, inOut);
              const newer = ramp(frame, at + 16, at + 26, 1, index === 2 ? 1 : 0.42);
              return (
                <div key={line} style={{ position: "relative", alignSelf: "flex-start" }}>
                  <div style={{ ...type(34 * k, 700), color: blue, opacity: ramp(frame, at, at + 10) * newer, marginBottom: 6 }}>{index + 1}</div>
                  <Line at={at} size={(lang === "nl" ? 94 : 104) * k} dim={newer}>{line}</Line>
                  <div style={{ position: "absolute", left: -8, right: -8, bottom: 40 * k, height: 12 * k, borderRadius: 6, background: blue, transform: `scaleX(${strike})`, transformOrigin: "left center" }} />
                </div>
              );
            })}
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 0, bottom: 0, display: "flex", alignItems: "center", opacity: 1 - ramp(frame, cut.hero, cut.hero + 10, 0, 1, inOut) }}>
            <Line at={cut.pain + 66} size={(lang === "nl" ? 150 : 124) * k} weight={900}>{words.turn}</Line>
          </div>
        </div>
      ) : null}

      {/* 3 to 5. The watch. */}
      {frame >= cut.hero && frame < cut.rivals + 6 ? (
        <Watch x={pose.x} y={pose.y} scale={pose.scale} focus={pose.focus} crown={ramp(radar, 50, 60) * (1 - ramp(radar, 126, 136))}>
          <Shot src={face.file} />
          {places >= 0 && dim > 0 ? <Spotlight slot={slotLit} circle={circleLit} strength={dim} /> : null}
          {page > 0 ? <Shot src={shots.page} opacity={page} /> : null}
          {map > 0 ? <Shot src={`${shots.radarFolder}/${String(step).padStart(2, "0")}.png`} opacity={map} /> : null}
        </Watch>
      ) : null}
      <Rain layout={layout} amount={near} layer={1} />
      {!layout.wide && Math.max(lean, close) > 0 ? (
        <div style={{ position: "absolute", left: 0, top: 0, width: W, height: 620, opacity: Math.max(lean, close), background: `linear-gradient(to bottom, ${night} 0%, ${night} 52%, rgba(4,7,12,0) 100%)` }} />
      ) : null}

      {frame >= cut.hero && frame < cut.places + 12 ? (
        <div style={beside}>
          <div style={{ position: layout.wide ? "relative" : "absolute", top: 0, left: 0 }}>
            {frame < cut.hero + 62 ? (
              <>
                <Line at={cut.hero + 12} until={cut.hero + 60} size={128 * k} weight={900}>{words.look[0]}</Line>
                <Line at={cut.hero + 18} until={cut.hero + 60} size={128 * k} weight={900} colour={blue}>{words.look[1]}</Line>
              </>
            ) : (
              <>
                <Line at={cut.hero + 62} until={cut.places + 10} size={(lang === "nl" ? 64 : 68) * k} weight={800}>{words.promise[0]}</Line>
                <Line at={cut.hero + 66} until={cut.places + 10} size={(lang === "nl" ? 64 : 68) * k} weight={800} colour={blue}>{words.promise[1]}</Line>
                <div style={{ height: 22 }} />
                <Line at={cut.hero + 76} until={cut.places + 10} size={31 * k} weight={550} colour={grey}>{words.lapse}</Line>
              </>
            )}
          </div>
        </div>
      ) : null}

      {frame >= cut.places && frame < cut.radar + 10 ? (
        <div style={beside}>
          <div style={{ position: "relative", height: 110 * k }}>
            {words.places.map((line, index) => (
              <div key={line} style={{ position: "absolute", top: 0, left: 0 }}>
                <Line at={cut.places + 12 + index * 36} until={index === 2 ? cut.radar + 8 : cut.places + 12 + (index + 1) * 36} size={(index === 2 ? (layout.wide ? 68 : 80) : 96) * k} weight={900} colour={index === 1 ? blue : white}>
                  {line}
                </Line>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {frame >= cut.radar && frame < cut.rivals + 4 ? (
        <div style={beside}>
          <Line at={cut.radar + 14} until={cut.rivals + 2} size={112 * k} weight={900}>{words.radar[0]}</Line>
          <Line at={cut.radar + 20} until={cut.rivals + 2} size={(lang === "nl" ? 84 : 92) * k} weight={900} colour={blue}>{words.radar[1]}</Line>
          <div style={{ height: 26 }} />
          <Line at={cut.radar + 56} until={cut.rivals + 2} size={40 * k} weight={650} colour={grey}>{words.crown}</Line>
        </div>
      ) : null}

      {/* 6. The comparison. */}
      {frame >= cut.rivals && frame < cut.end + 8 ? (
        <div style={{ ...alone, opacity: 1 - ramp(frame, cut.end - 8, cut.end + 4, 0, 1, inOut) }}>
          <Line at={cut.rivals + 4} size={108 * k} weight={900}>{words.question[0]}</Line>
          <Line at={cut.rivals + 8} size={108 * k} weight={900} colour={blue}>{words.question[1]}</Line>
          <div style={{ height: 64 * k }} />
          {(named ? words.rivals : [words.others]).map((rival, index) => (
            <Row key={rival.name} at={cut.rivals + 22 + index * 14} k={k} name={rival.name} note={rival.note} ours={false} />
          ))}
          <Row at={cut.rivals + 22 + (named ? 2 : 1) * 14 + 4} k={k} name={words.name} note={words.ours} ours />
          <div style={{ height: 30 * k }} />
          {named ? <Line at={cut.rivals + 62} size={28 * k} weight={500} colour={grey}>{words.asOf}</Line> : null}
        </div>
      ) : null}

      {/* 7. The name. */}
      {frame >= cut.end ? (
        <div style={{ ...alone, alignItems: "flex-start" }}>
          <Img
            src={staticFile("icon.png")}
            style={{ width: 250 * k, height: 250 * k, borderRadius: "50%", marginBottom: 46 * k, opacity: ramp(frame, cut.end + 2, cut.end + 14), transform: `scale(${0.7 + 0.3 * ramp(frame, cut.end + 2, cut.end + 22)})`, transformOrigin: "left center" }}
          />
          <Line at={cut.end + 8} size={(lang === "nl" ? 150 : 158) * k} weight={900}>{words.name}</Line>
          <div style={{ height: 30 * k }} />
          <div style={{ display: "flex", gap: 22 * k, flexWrap: "wrap" }}>
            {words.end.map((word, index) => (
              <Line key={word} at={cut.end + 22 + index * 9} size={(lang === "nl" ? 46 : 56) * k} weight={800} colour={index === 0 ? blue : white}>{word}</Line>
            ))}
          </div>
          <div style={{ height: 44 * k }} />
          <Line at={cut.end + 52} size={34 * k} weight={600} colour={grey}>{words.store} · {words.credit}</Line>
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

/** One app in the comparison: its name, what its watch face offers, and a mark drawn stroke by stroke. */
const Row: React.FC<{ at: number; k: number; name: string; note: string; ours: boolean }> = ({ at, k, name, note, ours }) => {
  const frame = useCurrentFrame();
  const enter = ramp(frame, at, at + 14);
  const draw = ramp(frame, at + 8, at + 22, 0, 1, inOut);
  if (frame < at) return <div style={{ height: 196 * k, marginBottom: 22 * k }} />;
  return (
    <div style={{ position: "relative", height: 196 * k, marginBottom: 22 * k, opacity: enter, transform: `translateX(${(1 - enter) * 60}px)`, alignSelf: "stretch", clipPath: ours ? `inset(0 ${100 - 100 * ramp(frame, at, at + 18)}% 0 0 round ${40 * k}px)` : undefined }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 40 * k, background: ours ? blue : "rgba(255,255,255,0.06)" }} />
      <div style={{ position: "absolute", left: 44 * k, top: 36 * k }}>
        <div style={{ ...type(76 * k, 850), color: ours ? "#04121F" : white }}>{name}</div>
        <div style={{ ...type(38 * k, 600), color: ours ? "#04121F" : grey, marginTop: 12 * k, letterSpacing: "-0.01em" }}>{note}</div>
      </div>
      <svg width={84 * k} height={84 * k} viewBox="0 0 84 84" style={{ position: "absolute", right: 40 * k, top: 56 * k }}>
        {ours ? (
          <path d="M14 44 L34 64 L70 22" fill="none" stroke="#04121F" strokeWidth={11} strokeLinecap="round" strokeLinejoin="round" strokeDasharray={90} strokeDashoffset={90 * (1 - draw)} />
        ) : (
          <>
            <path d="M20 20 L64 64" fill="none" stroke={grey} strokeWidth={9} strokeLinecap="round" strokeDasharray={64} strokeDashoffset={64 * (1 - ramp(draw, 0, 0.5, 0, 1, (t) => t))} />
            <path d="M64 20 L20 64" fill="none" stroke={grey} strokeWidth={9} strokeLinecap="round" strokeDasharray={64} strokeDashoffset={64 * (1 - ramp(draw, 0.5, 1, 0, 1, (t) => t))} />
          </>
        )}
      </svg>
    </div>
  );
};
