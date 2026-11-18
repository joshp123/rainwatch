import React from "react";
import { Composition, continueRender, delayRender, staticFile } from "remotion";
import { Film, FilmProps } from "./Film";
import { cut, fps } from "./theme";

// Inter (SIL Open Font Licence) for the film's words; SF Compact Rounded, the watch's face font,
// for the app's words, copied from macOS by render.sh and never committed (Apple's licence).
const wait = delayRender("fonts");
Promise.all([
  new FontFace("Inter", `url(${staticFile("fonts/Inter.ttf")})`, { weight: "100 900" }).load(),
  new FontFace("SF Compact Rounded", `url(${staticFile("fonts/SFCompactRounded.ttf")})`, { weight: "1 1000" }).load(),
]).then((faces) => {
  faces.forEach((face) => document.fonts.add(face));
  continueRender(wait);
});

const sizes = { "9x16": [1080, 1920], "16x9": [1920, 1080] } as const;

export const Root: React.FC = () => (
  <>
    {(["en", "nl"] as const).flatMap((lang) =>
      (["9x16", "16x9"] as const).flatMap((shape) =>
        [true, false].map((named) => (
          <Composition<any, FilmProps>
            key={`${lang}-${shape}-${named}`}
            id={`${lang}-${shape}${named ? "" : "-unnamed"}`}
            component={Film}
            width={sizes[shape][0]}
            height={sizes[shape][1]}
            fps={fps}
            durationInFrames={cut.total}
            defaultProps={{ lang, named }}
          />
        )),
      ),
    )}
  </>
);
