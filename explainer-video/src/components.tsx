import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {fontFamily, usePalette} from './theme';

export const SceneFrame: React.FC<{children: React.ReactNode}> = ({children}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const p = usePalette();
  const opacity = interpolate(
    frame,
    [0, 12, durationInFrames - 15, durationInFrames - 1],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}
  );
  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        background: `radial-gradient(1200px 700px at 70% 20%, ${p.bgGlow} 0%, ${p.bg} 60%)`,
        fontFamily,
        color: p.text,
        opacity,
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      {children}
    </div>
  );
};

export const Caption: React.FC<{text: string}> = ({text}) => {
  const frame = useCurrentFrame();
  const p = usePalette();
  const opacity = interpolate(frame, [10, 20], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        bottom: 46,
        left: 160,
        right: 160,
        textAlign: 'center',
        fontSize: 30,
        fontWeight: 500,
        lineHeight: 1.4,
        color: p.text,
        background: p.captionBg,
        padding: '18px 36px',
        borderRadius: 16,
        opacity,
      }}
    >
      {text}
    </div>
  );
};

export const SpringIn: React.FC<{
  delay?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({delay = 0, children, style}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: frame - delay, fps, config: {damping: 14, mass: 0.8}});
  return (
    <div
      style={{
        transform: `translateY(${(1 - s) * 60}px) scale(${0.85 + s * 0.15})`,
        opacity: s,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

export const Card: React.FC<{
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({children, style}) => {
  const p = usePalette();
  return (
    <div
      style={{
        background: p.card,
        border: `1px solid ${p.cardBorder}`,
        borderRadius: 24,
        padding: 32,
        boxShadow: p.shadow,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

export const Row: React.FC<{
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({children, style}) => (
  <div style={{display: 'flex', alignItems: 'center', gap: 16, ...style}}>
    {children}
  </div>
);

export const KineticTitle: React.FC<{
  words: string[];
  delay?: number;
  fontSize?: number;
  accent?: number[];
}> = ({words, delay = 0, fontSize = 96, accent = []}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = usePalette();
  return (
    <div style={{display: 'flex', gap: 24, flexWrap: 'wrap', justifyContent: 'center'}}>
      {words.map((w, i) => {
        const s = spring({
          frame: frame - delay - i * 4,
          fps,
          config: {damping: 13, mass: 0.7},
        });
        return (
          <span
            key={i}
            style={{
              fontSize,
              fontWeight: 800,
              letterSpacing: -2,
              color: accent.includes(i) ? p.crimson : p.text,
              transform: `translateY(${(1 - s) * 80}px)`,
              opacity: s,
              display: 'inline-block',
            }}
          >
            {w}
          </span>
        );
      })}
    </div>
  );
};
