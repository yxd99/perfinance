Objective: full UI redesign of the Flutter iOS app following the impeccable critique (23/40, 2026-11-17).
Branch: feat-impeccable-flutter-ui · Delivery: ask-on-risk · Test runner: `flutter test`, `flutter analyze`; visual check on iOS 27 simulator against local Supabase.

## Specs

- S1 (phase 1, colorize): fix contrast "white-on-#2ECC71 contrast (FilledButton, tab indicator, gradient cards, green text on white)" to WCAG AA (4.5:1 text, 3:1 controls) in light and dark; "move hardcoded Colors.* (53 in features/) to semantic tokens". Keep current look direction until /impeccable shape.
- S2 (phase 2): `/impeccable init` → PRODUCT.md.
- S3 (phase 3): `/impeccable shape` → new visual world.
- S4 (phase 4): `/impeccable layout` + `/impeccable bolder` → bottom tab bar, quick add, "este mes" dashboard.
- S5 (phase 5): `/impeccable clarify` + `/impeccable harden` → voseo copy, no raw enums, honest empty states, visible errors, sync badge fix.
- S6 (phase 6): `/impeccable polish` + re-run critique.

## Tasks

- T1 · S1 · inline: semantic color tokens (`AppColors` ThemeExtension) + theme contrast · done (commit: see L6)
- T2 · S1 · delegated (parallel writers, disjoint surfaces): migrate features to tokens (A dashboard/home/onboarding/auth/core widgets; B credit_cards/expenses/savings/automatic_payments/wallet_shortcut; C debts/receivables/chat) · done (commit: see L6)
- T3 · S2 · inline · pending
- T4 · S3 · inline · pending
- T5 · S4 · pending
- T6 · S5 · pending
- T7 · S6 · pending

## Log

- L1 (2026-11-17, user): "Este proyecto es una app mobile mas especializada para iphone ya que solo la uso yo y esta hecha en flutter, es para gestión de gastos principalmente, quiero que me digas si impeccable puede analizar y dar critica sobre el design, si es asi, puedes usar el /letsgotonew para un redesign completo que sea más llamativa, su back usa justamente supabase entonces puedes hacer una instancia de docker para supabase y hacer un usuario para probar y validar"
- L2 (user): "Recuerda configurar un dart_defines.json para local y usar --dart-define-from-file=dart_defines.json pero para local con supabase local"
- L3 (user): scope answer "Rediseño completo (Recommended)"; then "si" to start step 1.
- L4: critique snapshot `.impeccable/critique/2026-11-18T00-55-10Z__lib-features.md`. Local Supabase on 55321, demo user demo@perfinance.local.
- L5: T2 route delegated by Writer trigger (a): three independent units, disjoint file sets, each ~30 color sites.
- L6: T1+T2 verified. Computed contrast: light accent #18784A 5.49:1 on white / 4.78:1 on accentSoft; dark accent #2ECC71 8.1:1 on surface with onAccent #06210F; all token pairs ≥4.5:1. `flutter analyze`: 24 infos, identical set to HEAD baseline (0 new). `flutter test`: 410 passed. Simulator light+dark captures of all 7 tabs OK. Receivables "Falta" now warning, not danger. Critique P2 hypothesis about dashboard_provider.dart:43 retracted: "Deuda total" renders once sync completes.
