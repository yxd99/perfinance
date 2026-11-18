# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

The author plus a few people close to them (iPhone and Android). The author is an expert; the newer users learn the app through the first-run guide, which covers every section and can be replayed from Más › Guía de la app. Everyone opens the app for two jobs:

1. **Review the month**: how much has been spent so far, card debt, and what is due soon.
2. **Log by hand** what Apple Wallet does not capture: cash, Nequi/debit and other non-card payments.

Card payments arrive on their own through the Apple Wallet shortcut, often while the app is closed.

## Product Purpose

Personal expense control. Success means knowing at a glance whether this month is on track or overspending.

## Positioning

A private, offline-first expense tracker built around the author's real money flow: Colombian cards with cut-off days, management fees and minimum payments; debts and money owed to the author; and automatic logging of Apple Wallet payments through an iOS shortcut, without opening the app.

## Operating Context

- Glanced at on the go, one-handed; manual logging happens right after paying, often standing.
- Works fully offline; every read and write hits local SQLite, Supabase is backup and sync.
- Money in Colombian pesos (COP), no decimals in display.
- Apple Wallet shortcut creates expenses labelled `[Wallet]: <merchant>`.

## Capabilities and Constraints

- Records **expenses only**. Income is out of scope; never propose it.
- Credit cards: alias, cut-off day, management fee, minimum payment per month, payments; can be deactivated without deletion.
- Payment methods (savings): cash, debit, other.
- Debts the user owes: active, paid, hidden.
- Money owed to the user (receivables): active, settled, written off, hidden; registered debtors get a read-only mirrored debt.
- Automatic payments generate recurring expenses; active or paused.
- Dashboard and a financial-advisor chat.
- Hide-values toggle for amounts.
- Balances are computed over the full local history.

## Brand Commitments

- Name: PerFinance. Existing logo asset: `assets/images/perfinance-logo.png` (whether to keep or redraw it is undecided).
- Interface copy in Colombian neutral Spanish, addressing the user as tú ("tienes", "registra"). No voseo, no regional slang.

## Evidence on Hand

- Real usage data lives only on the author's device and Supabase; design work uses the local demo user (`demo@perfinance.local`) with seeded data.
- No testimonials, metrics or external users exist; do not fabricate them.

## Product Principles

1. **This month first.** The first thing visible answers "am I on track this month?".
2. **Logging is a seconds-long task.** Manual expense entry must be reachable with the thumb from anywhere in the app.
3. **Debt is a number to watch, not decoration.** Card and loan debt stay honest and prominent, never softened.
4. **Works without signal.** No screen may depend on connectivity to be useful.
5. **Fast for experts, findable for newcomers.** Keep density and speed, but no action may live only behind a gesture (long-press, swipe): every row action is also visible. Labels name what they do ("+ Egreso", "Nueva deuda", "Tarjetas de crédito", "Cuentas de ahorro"). The first-run guide explains each section once; it is not repeated in the UI.

## Accessibility & Inclusion

WCAG AA contrast in light and dark mode (established in `lib/core/theme/app_colors.dart`). Respect iOS Dynamic Type and Reduce Motion.
