import React from 'react';
import {loadFont} from '@remotion/google-fonts/Inter';

export const {fontFamily} = loadFont('normal', {
  weights: ['400', '500', '600', '700', '800'],
});

export type Palette = {
  bg: string;
  bgGlow: string;
  text: string;
  crimson: string;
  card: string;
  cardBorder: string;
  muted: string;
  green: string;
  track: string;
  barNeutral: string;
  starOff: string;
  captionBg: string;
  shadow: string;
  labelPaper: string;
  labelInk: string;
};

export const DARK: Palette = {
  bg: '#121212',
  bgGlow: '#1e1e1e',
  text: '#FFFFFF',
  crimson: '#C8203A',
  card: '#1D1D1D',
  cardBorder: '#2E2E2E',
  muted: '#9A9A9A',
  green: '#3BB273',
  track: '#2a2a2a',
  barNeutral: '#4a4a4a',
  starOff: '#444444',
  captionBg: 'rgba(18,18,18,0.72)',
  shadow: '0 24px 60px rgba(0,0,0,0.5)',
  labelPaper: '#FFFFFF',
  labelInk: '#111111',
};

export const LIGHT: Palette = {
  bg: '#F6F6F7',
  bgGlow: '#FFFFFF',
  text: '#121212',
  crimson: '#C8203A',
  card: '#FFFFFF',
  cardBorder: '#E4E4E7',
  muted: '#6B6B72',
  green: '#2E9E63',
  track: '#ECECEF',
  barNeutral: '#BDBDC4',
  starOff: '#D0D0D5',
  captionBg: 'rgba(255,255,255,0.85)',
  shadow: '0 24px 60px rgba(17,17,17,0.10)',
  labelPaper: '#FFFFFF',
  labelInk: '#111111',
};

export type ThemeName = 'dark' | 'light';

export const ThemeContext = React.createContext<Palette>(DARK);

export const usePalette = (): Palette => React.useContext(ThemeContext);

export const paletteFor = (theme: ThemeName): Palette =>
  theme === 'light' ? LIGHT : DARK;

export const CAPTIONS: string[] = [
  'Meet TruERP — the GST billing software built for growing businesses. Everything you need to sell, stock, and manage your team, in one place.',
  'Create GST-compliant sales invoices in seconds. Pick a customer, add items, and taxes are calculated automatically. Choose from customizable templates, share a PDF, and generate e-invoices with ease.',
  "At the counter, TruERP's point of sale keeps the line moving. Scan barcodes, hold bills as drafts, manage cash sessions, and keep billing even when the internet goes down.",
  'Track stock across stores and warehouses in real time. Print professional barcode labels on thermal printers or A4 label sheets, straight from your product list.',
  'Pay your team with confidence. Record attendance, process salaries, track advances, and log every payroll payment.',
  'Turn shoppers into regulars with built-in loyalty. Customers earn points on every purchase and redeem them right at checkout.',
  'TruERP. Available on the web and as a desktop app for Mac and Windows. Simplify your business today.',
];

export const SCENE_DURATIONS = [285, 426, 337, 300, 249, 219, 204];
