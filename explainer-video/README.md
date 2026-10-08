# TruERP Explainer Video

Remotion 4.x motion-graphics explainer for TruERP. 1920x1080 @ 30fps, H.264 MP4, macOS `say` voiceover (Samantha), per-scene WAVs in `public/audio/`.

## Setup

```bash
npm install
```

## Regenerate voiceover

```bash
say -v Samantha -o public/audio/sceneN.wav --data-format=LEI16@44100 "<scene line>"
```

Measure durations with `afinfo public/audio/sceneN.wav` and update `SCENE_DURATIONS` in `src/theme.ts` (frames = seconds × 30 + ~24 padding).

## Preview

```bash
npx remotion studio
```

## Render

```bash
npx remotion render TruERP out/truerp-explainer.mp4          # dark theme
npx remotion render TruERPLight out/truerp-explainer-light.mp4  # light theme
```

## Render a still frame

```bash
npx remotion still TruERP out/stills/frame-<N>.png --frame=<N>
```

## Typecheck

```bash
npx tsc --noEmit
```
