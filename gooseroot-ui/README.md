# Gooseroot

Gooseroot is a technology studio that builds web apps, mobile apps, custom software and AI automation. This UI kit is the source of truth for every Gooseroot product screen: the client portal, internal dashboards, and apps we design for ourselves. Its layout language (soft floating cards on a tinted page, a rounded colour rail, generous radii, friendly line icons) comes from modern productivity dashboards. All colour, type and shape come from the Lens brand identity.

**Tagline:** Where ideas and technology come together.

## Principles

1. **Light and calm by default.** Pages sit on a soft neutral grey (`bg` #F4F4F5), content lives in white cards (`surface`). Red is an accent, not a background, except for the sidebar rail, one promo card, and brand panels.
2. **One loud thing per view.** One primary button, one brand-gradient card, one highlighted word in a headline.
3. **Deep Wine for strong neutrals in light mode.** Dark buttons, tooltips and toasts use `ink` (Deep Wine) instead of black. The **dark theme** uses near-black neutral surfaces (`bg` #0B0A0B, `surface` #161314) so the reds stand out.
4. **Soft, round, wine-tinted depth.** Corners come from the radius scale (cards `radius-xl`, shell `radius-2xl`, pills `radius-pill`). Shadows are wine-tinted (`shadow-sm` → `shadow-lg`); the focused or most important row gets `shadow-md` (`is-raised`).
5. **Numbers first, words short.** Every card has one job and one key number or action.

## Colour

| Use | Tokens |
|---|---|
| Page / cards / subtle fills | `bg`, `surface`, `surface-2`, `tint` |
| Text | `heading`, `text`, `muted` |
| Lines | `line` (hairlines), `line-strong` (controls, dashed add tiles) |
| Brand accent | `primary` (icons, links, active states, progress), `primary-strong` (hover) |
| Brand gradient | `grad-start` → `grad-mid` → `grad-end` at 135°. Buttons use `grad-mid` → `grad-end` so white text passes 4.5:1. |
| Strong neutral | `ink` with `on-ink` |
| States | `success` / `success-tint`, `danger` / `danger-tint` |

Rules:
- Text on `grad-start` (Scarlet) must be at least 18px bold or 24px regular. Body text never sits on Scarlet.
- `success` is the only green and only means "done/positive". No orange, yellow, blue or purple anywhere. The brand forbids them.
- Dark theme: switch `<html data-theme="dark">`; surfaces are near-black, accents stay red. Every component works in both themes because it only reads tokens.

## Typography

Poppins only (Regular 400, Medium 500, Bold 700; files in `fonts/`). Headings are Bold with tight tracking (`h1` 34px, `h2` 24px, `h3` 18px). UI text is 14px (`body`, `label`), meta is 12px `caption`, eyebrows are 11px uppercase `overline` in `primary`. Use `.gr-grad-text` on one key word of a page greeting or hero headline, e.g. "What are your **plans** for today?".

## Layout

- **App shell** (`gr-shell`): 84px brand-gradient rail on the left (`gr-sidebar`), then `gr-shell__main` with the top bar (`gr-topnav`) and rows of cards in CSS grids with a 20px gap (`space-5`). Page padding is 24px.
- **Cards** have 24px padding (`space-6`) and a header row (`gr-card__head`): title + small text actions (Edit, Clear, Share).
- **Rows inside cards** (tasks, notifications, events) are `radius-lg` with 12–16px gaps.
- **Responsive.** There are five layouts, built into `bundle.css`. Use the layout classes (`gr-cols-2/3/4`, `gr-form2`, `gr-dash-hero`, `gr-dash-row3`, `gr-settings`, `gr-kanban`, `gr-signin`) instead of inline grid styles so they adapt.

  | Width | What changes |
  |---|---|
  | ≥ 1281px (desktop) | Full layouts; the rail is sticky. |
  | 1101–1280px (laptop) | The dashboard greeting takes its own row, and row 3 reflows. |
  | 1025–1100px (small laptop) | Search collapses to an icon, 3-col and 4-col grids go to 2 columns, and the kanban scrolls sideways. |
  | 761–1024px (tablet) | Top-bar tabs move to their own scrolling row, and sign-in stacks with the brand panel on top. |
  | ≤ 760px (phone) | The rail becomes a floating bottom tab bar, and a small wordmark appears in the top bar. Theme labels and the CTA collapse to icons. Cards, forms and settings go to one column, task rows stack, and modal buttons go full width. |
  | ≤ 420px (small phone) | Dashboard row 3 is one column, and the search icon is hidden. |

  Utilities: `gr-hide-md` / `gr-show-md` (switch at 1100px), `gr-hide-sm` / `gr-show-sm` (switch at 760px). Pages were checked from 320px to 1920px with no horizontal scrolling.

## Website components

For marketing sites use the **Website** group: `gr-nav` (navbar with a mobile menu), `gr-footer` (Deep Wine, `footer-bg`), `gr-price` (pricing cards, one `is-featured`) and the sign-in/sign-up forms (`AuthForms`). `gr-steps` (Stepper) shows project or onboarding phases. E-commerce and account flows: `ShopCard` (`gr-product`, `gr-qty`), `Payment` (UPI / card / net banking, `gr-summary` with GST), `RatingReview` (`gr-rsum`, `gr-review`, `gr-starinput`) and `CookieConsent` (bar + preferences; Reject must be as easy as Accept). Error pages (`ErrorPage`, `gr-error`): 401, 403, 404, 500, 502, 503. A single 0 is a gradient ring, and a double 00 is the Lens symbol.

Other patterns: `Banner`, `Snackbar`, `Drawer`, `FloatingAction`, `SpeedDial`, `QuickActions`, `TreeView`, `Divider`, `Skeleton`, `Appearance` and `Typography`.

## Iconography

Line icons on a 24px grid, 1.8px stroke, round caps and joins, `currentColor`. They're provided by the runtime: `<i data-icon="bell"></i>` + `Gooseroot.mount()` (see `components/index.d.ts` for the 50+ names). Standalone icons are `muted`, active ones `primary`. Icon wells (`gr-well`) put a `primary` icon on `tint`, or a white icon on the gradient for the primary feature. Never use emoji as icons, filled multicolour icons, or 3D clip-art.

## Logo

Use the Lens logo only from the runtime (`data-logo="wordmark|wordmark-white|wordmark-wine|symbol|symbol-white"`) or the Logos assets. Never redraw or recolour it. Rail: `symbol-white` at 44–48px. Sign-in and marketing panels: `wordmark-white` on the brand gradient, optionally with a giant `symbol-white` watermark at 8–10% opacity.

## Motion

- Hover lifts buttons 1px and adds `shadow-red`.
- Cards lift 2–4px with `shadow-md`.
- Durations are 150–250ms ease.
- Loading uses the Lens loader (`data-lens`): rings draw in, slide together, and the leaf opens. Skeletons (`gr-skel`) show for content.
- Respect `prefers-reduced-motion`.

## Voice in the UI

- Plain, friendly and specific. Use sentence case everywhere except overlines.
- Buttons start with a verb: "Add new board", "Accept invite", "Start your project".
- Empty states say what will appear and offer the action.
- Errors say how to fix them ("Enter an amount in ₹, e.g. 5,00,000").
- Use Indian formats: ₹ with lakh grouping, DD Mon dates, 12-hour times.

## Using the kit in code

1. Load `tokens.css` (generated from `tokens.json`), then `components/bundle.css`.
2. Add `components/bundle.js` and call `Gooseroot.mount()` after rendering, to draw icons, logos and loaders.
3. Build screens from the `gr-*` classes shown in each component's preview. The **Pages** group (Dashboard, ProjectBoard, Settings, SignIn, AllComponents) shows complete screens to copy from. **AllComponents** puts every website and app component on one responsive page.
