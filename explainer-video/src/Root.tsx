import React from 'react';
import {Audio, Composition, Sequence, staticFile} from 'remotion';
import {paletteFor, SCENE_DURATIONS, ThemeContext, ThemeName} from './theme';
import {
  Scene1Intro,
  Scene2Invoice,
  Scene3POS,
  Scene4Inventory,
  Scene5Payroll,
  Scene6Loyalty,
  Scene7Outro,
} from './scenes/Scenes';

const scenes = [
  Scene1Intro,
  Scene2Invoice,
  Scene3POS,
  Scene4Inventory,
  Scene5Payroll,
  Scene6Loyalty,
  Scene7Outro,
];

const TOTAL = SCENE_DURATIONS.reduce((a, b) => a + b, 0);

const Video: React.FC<{theme: ThemeName}> = ({theme}) => {
  let from = 0;
  return (
    <ThemeContext.Provider value={paletteFor(theme)}>
      {scenes.map((Scene, i) => {
        const start = from;
        from += SCENE_DURATIONS[i];
        return (
          <Sequence key={i} from={start} durationInFrames={SCENE_DURATIONS[i]}>
            <Audio src={staticFile(`audio/scene${i + 1}.wav`)} />
            <Scene />
          </Sequence>
        );
      })}
    </ThemeContext.Provider>
  );
};

export const Root: React.FC = () => {
  return (
    <>
      <Composition
        id="TruERP"
        component={Video}
        durationInFrames={TOTAL}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{theme: 'dark' as ThemeName}}
      />
      <Composition
        id="TruERPLight"
        component={Video}
        durationInFrames={TOTAL}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{theme: 'light' as ThemeName}}
      />
    </>
  );
};
