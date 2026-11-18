import React from "react";
import { Composition, continueRender, delayRender, staticFile } from "remotion";
import { Film, FilmProps } from "./Film";
import { cut, fps } from "./theme";

// Archivo (SIL Open Font Licence), with its weight and width axes.
const wait = delayRender("Archivo");
const font = new FontFace("Archivo", `url(${staticFile("fonts/Archivo.ttf")})`, { weight: "100 900", stretch: "62% 125%" });
font.load().then((loaded) => {
  document.fonts.add(loaded);
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
