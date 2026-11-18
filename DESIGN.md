---
name: PerFinance
description: A private, offline-first expense tracker whose month reads like a Colombian banknote.
colors:
  accent: "#5B3A7A"
  on-accent: "#FFFFFF"
  accent-soft: "#ECE4F2"
  canvas: "#F4EFE3"
  surface: "#FBF8F1"
  ink: "#1E1B18"
  text-muted: "#5E574C"
  divider: "#DCD3C1"
  track: "#E6DECD"
  positive: "#18784A"
  positive-soft: "#E3F3EA"
  warning: "#8A5300"
  warning-soft: "#FFF1D6"
  danger: "#C53030"
  on-danger: "#FFFFFF"
  danger-soft: "#FCE9E9"
  info: "#1F5F99"
  info-soft: "#E6EFF8"
  hero-start: "#5B3A7A"
  hero-end: "#432A5C"
  hero-debt-start: "#C53030"
  hero-debt-end: "#8E1F2C"
  on-hero: "#FFFFFF"
  on-hero-muted: "#E6FFFFFF"
  on-hero-soft: "#33FFFFFF"
  note-100k-green: "#2F6B4F"
  note-20k-blue: "#2C5A8C"
  note-2k-orange: "#A85A1C"
  note-5k-brown: "#7A4A2E"
  note-10k-rose: "#8A3B6E"
  dark-accent: "#C7A6E8"
  dark-on-accent: "#24123A"
  dark-accent-soft: "#2D2338"
  dark-canvas: "#14120F"
  dark-surface: "#221E19"
  dark-ink: "#EDE6D6"
  dark-text-muted: "#A89F8F"
  dark-divider: "#38322A"
  dark-track: "#38322A"
  dark-positive: "#4ADE80"
  dark-positive-soft: "#16301F"
  dark-warning: "#F5B544"
  dark-warning-soft: "#3A2C10"
  dark-danger: "#FF7B7B"
  dark-on-danger: "#2A0606"
  dark-danger-soft: "#3B1717"
  dark-info: "#7FB8F0"
  dark-info-soft: "#15263A"
  dark-note-100k-green: "#6FBF94"
  dark-note-20k-blue: "#7FA8DB"
  dark-note-2k-orange: "#E39A5B"
  dark-note-5k-brown: "#C49170"
  dark-note-10k-rose: "#D08AB8"
typography:
  display:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "36px"
    fontWeight: 800
    lineHeight: 1.22
    letterSpacing: "-1px"
    fontFeature: "tnum"
  headline-large:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "-0.5px"
  headline:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.29
    letterSpacing: "-0.5px"
  headline-small:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.33
    letterSpacing: "-0.4px"
  title:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.27
  title-small:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.43
    letterSpacing: "0px"
  body:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0px"
  body-small:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.33
    letterSpacing: "0px"
  label:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.43
    letterSpacing: "0px"
  label-small:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.45
    letterSpacing: "0px"
rounded:
  note-chip: "3px"
  account-chip: "4px"
  tap: "8px"
  control: "12px"
  card: "14px"
  full: "9999px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "28px"
components:
  month-note:
    backgroundColor: "{colors.hero-start}"
    textColor: "{colors.on-hero}"
    rounded: "{rounded.card}"
    padding: "20px"
  tab-add-button:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.full}"
    size: "52px"
  tab-item-selected:
    textColor: "{colors.accent}"
    typography: "{typography.label-small}"
  tab-item:
    textColor: "{colors.text-muted}"
    typography: "{typography.label-small}"
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.control}"
    padding: "14px 24px"
    height: "48px"
  inset-group:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.control}"
  account-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    padding: "10px 16px"
    height: "56px"
  account-note-chip:
    rounded: "{rounded.account-chip}"
    width: "34px"
    height: "22px"
  account-note-chip-mini:
    rounded: "{rounded.note-chip}"
    width: "22px"
    height: "14px"
  attention-row:
    backgroundColor: "{colors.warning-soft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "10px 14px"
    height: "48px"
  input-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "14px 16px"
  account-filter-chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
  account-filter-chip-selected:
    backgroundColor: "{colors.accent-soft}"
    textColor: "{colors.ink}"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.card}"
---

# Design System: PerFinance

## Overview

**Creative North Star: "Billete"**

The month is a Colombian banknote. The home screen opens on a purple note (the 50.000 peso bill) whose denomination is what has gone out so far this month, with a fine guilloché engraving and a ring that fills with the spending pace. Everything around it is banknote paper: a warm cream ground, near-black ink, and quiet grouped lists in the iOS idiom. The world replaced a generic green fintech look (green hero card, icon-in-circle tiles, scrollable top tabs); none of that vocabulary returns.

Identity and state are kept apart. Each account (credit card or payment method) wears the hue of a 2016-series note (100.000 green, 20.000 blue, 2.000 orange, 5.000 brown, 10.000 rose) as a small rectangular "mini bill". That hue says *which* account, never *how it is doing*. State is carried only by the AA-checked positive / warning / danger / info tokens.

The shell is native iOS: SF Pro through the system text theme so Dynamic Type works, a bottom tab bar with a raised central "+", large titles, inset grouped lists, Cupertino segmented controls and sheets. Brand expression lives where the platform leaves room: the note, the tint, the account hues, heavy tabular figures.

**Key Characteristics:**
- Banknote paper canvas (cream in light, ink-brown in dark) with one purple brand tint.
- One signature object per app: the month note with guilloché and the pace ring.
- Account identity through note hues on mini-bill chips, never through state colours.
- Heavy, tabular money figures; everything else is plain SF Pro.
- Flat surfaces with hairline dividers; the only shadow lifts the "+".

## Colors

Warm paper and ink with a single purple voice, five banknote hues for identity, and conventional state colours. All colours are reached through semantic roles (`context.colors.*`), never as loose values in screens. Light values are the unprefixed tokens; dark values carry the `dark-` prefix.

### Primary
- **50.000 Purple** (accent): the brand tint. Owns the month note, the selected tab, the "+" button, primary buttons, focus borders, the "Cancelar"/date link text and selected chips. Lifts to **Lilac Note** (dark-accent) in dark mode with a deep-plum on-accent so the button text stays readable.
- **Purple Wash** (accent-soft): tinted fill for selected chips and accent summaries.

### Neutral
- **Banknote Paper** (canvas): app background, app bars and the tab bar. Dark: **Night Paper** (dark-canvas).
- **Clean Paper** (surface): grouped lists, cards, inputs, sheets. Slightly lighter than the canvas so groups read as laid-on paper without shadow. Dark: **Raised Paper** (dark-surface).
- **Ink** (ink): primary text and amounts.
- **Faded Ink** (text-muted): secondary lines, unselected tabs, section headers, placeholder amounts.
- **Fold Line** (divider): 0.5pt hairlines between rows and around chips and inputs.
- **Track** (track): progress tracks, the sync banner and the segmented-control trough.

### Banknote hues (account identity)
- **100.000 Green**, **20.000 Blue**, **2.000 Orange**, **5.000 Brown**, **10.000 Rose** (note-* tokens; dark-note-* lifted for dark mode). Assigned by account creation order (`assignHueSlots`) so a new account never recolours an old one and the first five accounts never repeat; deactivated cards keep their slot. Falls back to a stable hash of the id while slots load.

### State
- **Positive** (positive / positive-soft): on track, collected, spend going down.
- **Warning** (warning / warning-soft): needs attention without urgency: cut-off days, overdue automatic payments, offline banner.
- **Danger** (danger / danger-soft): debt and destructive actions; also the pending-changes badge on "Más".
- **Info** (info / info-soft): neutral information (non-card accounts, received debts).

### Hero gradients
- **Month Note** (hero-start → hero-end, top-left to bottom-right): the 50.000 note. Identical in both themes; it is a printed object, not a surface. Text on it uses on-hero (white), on-hero-muted (white 90%) and on-hero-soft (white 20%, decoration only: guilloché lines, ring rosette).
- **Debt Note** (hero-debt-start → hero-debt-end): available for debt hero cards in screens not yet redesigned.

### Contrast (WCAG, computed from the tokens)
- Ink on canvas 14.9:1; faded ink on canvas 6.2:1, on surface 6.7:1.
- Purple on canvas 7.9:1; white on Month Note 9.0:1 (start) to 12.2:1 (end).
- Light states on surface/soft: danger 5.2:1, warning on warning-soft 5.7:1, positive 5.2:1, info 6.3:1; white on danger 5.5:1.
- Dark: ink 15.0:1 on canvas; faded ink 7.1:1 / 6.3:1; lilac accent 9.0:1; plum on lilac 8.2:1; danger 6.6:1, warning on its soft 7.5:1, positive 9.5:1, info 7.9:1 on surface.
- Note hues against surface: light 4.8:1 (orange, lowest) to 7.0:1; dark 6.0:1 to 7.5:1. They exceed the 3:1 non-text floor even though they are decorative.
- The divider (1.4:1) is a hairline, never the only boundary of a control that needs to be found.

### Named Rules
**The Identity Is Not State Rule.** A note hue identifies an account and nothing else. It never signals success, alert or error, and a state colour never identifies an account.

**The One Purple Rule.** Purple is the only brand colour. It marks the month note and interactive affordances; it is not used for decoration or illustration.

**The Roles Only Rule.** Screens read colours from `AppColors` roles. A raw hex in a feature file is a defect; an identity change touches one file.

## Typography

**Display Font:** SF Pro (Flutter system text theme, Material 2021 scale)
**Body Font:** SF Pro
**Label/Mono Font:** none distinct; amounts use SF Pro with tabular figures.

**Character:** One family, weight does the work. Money is heavy (800 at display, 700 in rows) and always tabular so columns align; labels and running text stay at system weights with Material's added tracking removed, because SF Pro carries its own.

### Hierarchy
- **Display** (800, 36, -1 tracking, tabular): the month amount on the note ("$896.900") and the amount being typed in "Registrá un egreso"; its placeholder "0" drops to weight 300 in faded ink.
- **Headline Large** (700, 32, -0.5): the month large title ("Noviembre") on Mes.
- **Headline** (700, 28): the day number inside the pace ring, tabular.
- **Headline Small** (700, 24, -0.4): large totals such as "Deuda total".
- **Title** (600, 22): sheet titles ("Registrá un egreso") and filter-sheet titles.
- **Title Small** (14, weight 700 tabular for row amounts; regular for day-group headings in Egresos).
- **Body** (400, 16): row names, list text, empty-state messages.
- **Body Small** (400, 12): one-line status under a row ("3 egresos"), pace sentence on the note, validation errors.
- **Label** (600, 14): field labels ("Monto", "Cuenta"), the note's "Gastado este mes".
- **Label Medium** (600, 12, +0.8 tracking, uppercase): inset-group section headers ("POR CUENTA", "DEUDA").
- **Label Small** (11; 600 selected / 500 unselected): tab labels, "de 30 días", the "Wallet" marker. 11pt is the floor.

All sizes come from the theme's scale and scale with the user's text size; screens do not hard-code point sizes.

### Named Rules
**The Tabular Money Rule.** Every amount and every count that sits in a column uses tabular figures (`kTabularFigures`).

**The Heavy Denomination Rule.** Only money gets weight 700–800. Labels and names never compete with the figure.

## Layout

A single scrolling column per tab, inside the safe area. The Mes screen uses a 20pt side gutter; Egresos, Más and the expense sheet use 16pt. Vertical rhythm is built from 4, 8, 12, 16, 20 and 28pt steps: 28pt above a section header, 8pt between header and group, 12pt between the title and the note, 8pt between stacked attention rows.

- **First viewport (Mes):** large month title with month chevrons, the month note (about 250pt tall: 20pt padding, 132pt ring), then "Por cuenta" rows, then debt and other sections.
- **Large titles:** Egresos and Más use an iOS-style large title app bar (44pt toolbar, 100pt expanded) that collapses on scroll. Mes draws its own large title row so the month can be tapped to pick another.
- **Shell:** bottom tab bar, 56pt plus the home-indicator inset: Mes · Egresos · + · Deudas · Más. Tabs are sections; the "+" is the one action and sits in the middle for the thumb.
- **Logging:** "+" opens "Registrá un egreso" as a bottom sheet with a drag handle; amount first with the numeric keyboard, account chips, description, "Guardar egreso".
- **Touch targets:** rows are at least 56pt, attention rows 48pt, buttons 48pt, the month title 44pt.

## Elevation & Depth

Flat by default. Depth comes from tone: Clean Paper groups sit on Banknote Paper canvas, separated by 0.5pt Fold Line hairlines. Cards, app bars and the navigation bar have zero elevation and no surface tint. The month note stands out through colour and engraving, not shadow.

### Shadow Vocabulary
- **Lift** (`0 3px 10px` in the shadow token: ink at 8% light, black at 30% dark): only under the raised "+" in the tab bar, which also sits 6pt above the bar's centre line.

### Named Rules
**The Paper On Paper Rule.** Grouping is done with a lighter paper and hairlines. A second shadow in the system needs a reason the "+" does not already cover.

## Shapes

Gentle, consistent corners. 14pt for cards and the month note; 12pt for inset groups, inputs, primary buttons, attention rows and summary bars; 8pt for small tap areas such as the month title; 4pt for the row-sized note chip and the "Wallet" marker; 3pt for the mini note chip in chips and the expense list. The "+" is a full circle. Account chips are rectangles in banknote proportion (34×22, 22×14), never circles; a circle tile around an icon is not part of this world.

The month note carries the guilloché: concentric 0.6pt hairlines every 7pt radiating from the ring's centre, clipped clear of the ring so the day stays legible, plus a 48-petal rosette band (0.7pt) around the ring. Engraving appears only inside the month note.

## Components

### Month note (signature)
The 50.000 note. Month Note gradient, 14pt radius, 20pt padding. Left column: "Gastado este mes" (or "Gastado en octubre" for past months) in label on-hero-muted, the amount at display scale (shrinks to fit, one line), and a pace sentence ("11% más que a esta altura de octubre") in body small. Right: the 132pt pace ring with the day number and "de 30 días". The arc (5pt, round caps, on-hero) fills with spend against last month at the same day. Screen readers get one sentence: label, amount (or "oculto"), pace and day. Loading shows the same note shape with a small white spinner.

**Motion:** the arc fills once on first build, 900ms ease-out-expo. With Reduce Motion (`MediaQuery.disableAnimationsOf`) it renders filled, static.

### Tab bar
Canvas background, 0.5pt top hairline, 56pt. Items use SF-style Cupertino glyphs at 26pt, filled when selected; selected tint is accent, unselected faded ink; labels at label small. No indicator pill, no splash. "Más" carries a danger badge with the count of local changes not yet uploaded, announced as "Más, N cambios sin subir".

### Add button
52pt accent circle with a white (dark: plum) plus, lifted 6pt with the Lift shadow. Light haptic on tap. Announced as "Registrar egreso".

### Buttons
- **Primary (filled):** accent fill, on-accent text, 12pt radius, 48pt minimum height, 14×24 padding, no elevation ("Guardar egreso").
- **Text links:** accent text at weight 600 for inline actions ("Cancelar", the date value in the form).

### Account note chips
Rounded rectangles in the account's note hue: 34×22 on account rows, 22×14 inside filter chips, expense rows and the form's account choices. Hidden from screen readers; the account name next to them carries the meaning.

### Chips
Surface background, divider border, ink label; selected uses Purple Wash with an accent checkmark. Used for account choice in the expense sheet and account filters in Egresos. "Nueva cuenta" sits last with an accent plus.

### Inset groups and rows
Surface, 12pt radius, rows separated by 0.5pt hairlines (indented 16pt, or 56pt when rows lead with an icon in Más). Account row: note chip, name in body, one status line in body small faded ink (up to two lines), amount right in bold tabular title small. Section headers above groups: uppercase label medium, faded ink, +0.8 tracking.

### Attention rows
Warning-soft fill, 12pt radius, 48pt min, warning glyph, ink text at 600 with tabular figures, optional detail line in warning, chevron when tappable. Used for cut-off days and overdue items on Mes.

### Inputs / Fields
Filled with surface, 12pt radius, divider border, 14×16 content padding. Focus: 2pt accent border. Errors: body small in danger under the field. The amount field is borderless: "$" prefix in faded ink, display-scale tabular figure.

### Segmented control
Native Cupertino sliding segmented control for date filters in Egresos ("Hoy", "Ayer", "Otra fecha"): track trough, surface thumb, ink labels (600 selected, 500 otherwise).

### Banners
Sync: track background, small accent spinner, "Sincronizando datos...". Offline: warning-soft background, warning text, "Sin conexión. Los datos se sincronizarán al recuperar la red."

### Wallet marker
A 4pt-radius outlined tag ("Wallet") in label small faded ink next to expenses created by the Apple Wallet shortcut.

### Motion
Platform transitions: Cupertino push on iOS, fade-upwards on Android; sheets rise and dismiss by swipe. The pace ring fill is the only custom animation and respects Reduce Motion. Theme switches snap rather than interpolate colours.

### Not yet in the system
Deudas (body below the shell), Tarjetas, Me deben, Auto-pagos, the financial-advisor chat and login still use pre-redesign layouts rendered on the new tokens. They are not reference material for new surfaces. The logo (`assets/images/perfinance-logo.png`) is undecided: keep or redraw.

## Do's and Don'ts

### Do:
- **Do** read every colour from `AppColors` roles; add a role before adding a hex.
- **Do** mark accounts with a note-hue chip in banknote proportion (34×22 on rows, 22×14 inline), assigned by `assignHueSlots`.
- **Do** set every amount in tabular figures; month and total amounts at display or headline weight 700–800.
- **Do** keep the month note as the first thing on Mes, with guilloché only inside it.
- **Do** render the pace ring static when Reduce Motion is on.
- **Do** keep tappable targets at 44pt or more (rows 56pt, buttons 48pt).
- **Do** design and check both appearances; dark mode uses the dark-* tokens, with the month note unchanged.
- **Do** write UI copy in Spanish with voseo ("Registrá un egreso", "Reactivala").

### Don't:
- **Don't** use a note hue to signal state, or a state colour to identify an account.
- **Don't** bring back the old fintech vocabulary: green hero card, icons inside tinted circles as tiles, scrollable top tabs.
- **Don't** add shadows to cards or groups; the "+" is the only lifted element.
- **Don't** spread guilloché or engraving outside the month note.
- **Don't** hard-code font sizes outside the theme scale; Dynamic Type must keep working.
- **Don't** introduce a second brand colour or a display typeface for UI chrome.
