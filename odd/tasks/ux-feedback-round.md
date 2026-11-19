UX fixes from the first external user's feedback, designed with impeccable (Operate mode, Billete world).
Branch: yxd99/crinoid · Delivery: ask-on-risk · Tests: `flutter test`, `flutter analyze`.

## Specs

- S1 Onboarding: "quiero que agregues un onboarding completo axhaustivo". Covers every section (Mes, registrar egreso, Egresos, Tarjetas de crédito, Cuentas de ahorro, Deudas, Me deben, Auto-pagos, Asesor/Wallet/ajustes), ends with a step to create the first accounts, and can be replayed from Más.
- S2 Add-expense button: "un boton que se identifique que sea para agregar egreso ya que me indicaron que puede ser mejor en otro lado" + "Digo, en "Deudas", ya que es un boton "+" al lado del titulo". The tab bar "+" gets a visible label ("Egreso"); the Deudas title "+" becomes a labelled "Nueva deuda" button.
- S3 Menu: "en el menu que dice "ahorros" y "tarjetas" quiero que se especifique "Tarjetas de Credito" o "Cuentas de ahorro"".
- S4 Account selection in the expense form: "en el registro de los egresos se vea de otra forma ya que con cheaps puede haber muchas tarjetas de credito y muchas cuentas de ahorro registradas que luego puede ser tedioso encontrarlas". Replace the chip wrap with a selected-account row that opens a searchable picker grouped by type.
- S5 Savings copy: "el copy de "ahorro" que lo confundio un poco (vista para registrar una cuenta de ahorro)".
- S7 Language: "Siento que los terminos son argentinos, cambialos a colombianos neutro". All UI copy, AI prompts and edge-function messages move from voseo to Colombian neutral Spanish with tú; "plata" becomes "dinero"; CLAUDE.md/PRODUCT.md/DESIGN.md rules updated.
- S8 Account color: "Veo que algunas tarjetas tienen colores, haz que se pueda escoger". User chose cloud storage (synced). Nullable `color_slot` 0..4 on credit_cards and payment_methods; null keeps the automatic hue.
- S6 Visible actions: "las acciones que hay que mantener presionado (como eliminar) no son tan intuitivas, que seria mejor dejarlas a simple vista del usuario". Every row whose actions were swipe/long-press only gets a visible "⋯" actions button; swipe stays as a shortcut; no long-press-only actions remain.

## Tasks

- T1 S3,S5 copy: menu labels + savings screens/forms copy · inline · GREEN, commit pending (signing key needs passphrase)
- T2 S2 labelled add-expense tab button + "Nueva deuda" · inline · GREEN, commit pending (signing key needs passphrase)
- T3 S6 RowActionsButton on expenses, debts, cards, savings, receivables, auto-payments · inline · GREEN, commit pending (signing key needs passphrase)
- T4 S4 account picker sheet with search and groups · inline · GREEN, commit pending (signing key needs passphrase)
- T5 S1 exhaustive onboarding + replay from Más · inline · GREEN, commit pending (signing key needs passphrase)
- T7 S7 voseo -> es-CO tú across lib, test, supabase/functions, docs · inline · GREEN (587 Flutter + 14 Deno), commit pending; edge functions need deploy
- T8 S8 color_slot: migration 017, SQLite v16, models, repos, pull, picker in both forms · inline · GREEN (596 tests), applied to LOCAL Supabase only; production `supabase db push` pending user OK; independent verifier: 1 blocker fixed (v16 upgrade now clears credit_cards/payment_methods sync cursors so late-updating devices backfill color_slot instead of pushing null over it), RED->GREEN in migration_v16_test; 597 tests
- T6 PRODUCT.md / DESIGN.md updated to the new truth · inline · GREEN, commit pending (signing key needs passphrase)

## Log

- L1 (2026-11-18) "La app crecio y ya la usa otra persona y me dio feedback: quiero que agregues un onboarding completo axhaustivo, ademas un boton que se identifique que sea para agregar egreso ya que me indicaron que puede ser mejor en otro lado, ademas en el menu que dice "ahorros" y "tarjetas" quiero que se especifique "Tarjetas de Credito" o "Cuentas de ahorro", también quiero que en el registro de los egresos se vea de otra forma ya que con cheaps puede haber muchas tarjetas de credito y muchas cuentas de ahorro registradas que luego puede ser tedioso encontrarlas, ademas del copy de "ahorro" que lo confundio un poco (vista para registrar una cuenta de ahorro), las acciones que hay que mantener presionado (como eliminar) no son tan intuitivas, que seria mejor dejarlas a simple vista del usuario por ejemplo, revisa con impeccable tambien este tema y haz el design correspondiente y los fixes"
- L2 (2026-11-18) "Digo, en "Deudas", ya que es un boton "+" al lado del titulo"
- L3 PRODUCT.md said "Built for one expert / no feature tours"; L1 overrides it (a second user now). PRODUCT.md updated.
- L4 (2026-11-18) "Puedes levantar supabase para probar tambien" — reused running local stack perfinance-ui (:55321, migrations 001-016, demo@perfinance.local, password reset locally to demo1234, +4 local savings accounts to exercise search). Local defines in session scratchpad, never the repo's dart_defines.json (points to production).
- L5 Evidence: RED observed per task; full suite `flutter test` 587 passed; `flutter analyze lib` only 4 pre-existing infos (debt_detail_screen, process_automatic_payments_service). `git commit` fails: SSH signing key prompts for a passphrase; changes staged/unstaged for the user to commit.
- L6 (2026-11-18) "Siento que los terminos son argentinos, cambialos a colombianos neutro" — chose tú (direct mapping of existing informal voseo). Explicit word map script, 47 code files + 4 docs; odd/ logs left verbatim.
- L7 (2026-11-18) "Veo que algunas tarjetas tienen colores, haz que se pueda escoger"; answer to storage question: "En la nube (Recomendado)". Local REST check: PATCH color_slot=3 accepted, 7 rejected (400).
- L8 (2026-11-18) User: "Mejor continua y luego aplico yo la migracion" — do not push 017 to production; apply before merging to main (push to main auto-publishes the APK and the new app would fail to push cards/accounts without the column).
