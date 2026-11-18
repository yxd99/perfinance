---
version: 1
slug: "lib-features-home-home-screen-dart"
primary_target: "lib/features/home/home_screen.dart"
related_targets: ["lib/features/dashboard/dashboard_screen.dart","lib/features/expenses/expenses_screen.dart"]
---

Scope: app shell + Mes (month) screen + Egresos + quick-add sheet. Visitor mode: Operate. Platform: iOS (Flutter).

Audience/job: single expert user, one-handed; review the month and log manual expenses (cash, Nequi) in seconds. Constraints: offline-first, voseo copy, SF Pro + Dynamic Type, 44pt targets, WCAG AA (AppColors tokens). Chosen sketch: .impeccable/mocks/decision/model-pick.html.

## Direction contract

THESIS: The month reads like a Colombian banknote: the spend-to-date is the denomination. Refuses the fintech default of green hero card + icon-in-circle tiles + scrollable top tabs.

OWN-WORLD: Banknote paper ground #F4EFE3 with ink #1E1B18; brand/shell colour is the 50.000 purple (#5B3A7A) owning the month note, active tab and the "+". Each account carries a 2016-series note hue (100k green, 20k blue, 2k orange, 5k brown, 10k red) as identity chips, assigned stably by account id. State colours stay the AA tokens (danger, warning, positive); paid/settled items are stamped, never vanish. Fine guilloché line texture only inside the month note. SF Pro throughout; big amounts heavy with tabular figures. Dark mode: ink ground, same note hues lifted for AA.

STORY: Open the app, see how much went out this month and whether the pace beats last month; spot what needs attention (cut-off, overdue); tap "+" with the thumb and log an expense in seconds.

FIRST VIEWPORT: Large title "Noviembre". Month note (purple, full width, ~250pt): label "Gastado este mes", amount at display scale bottom-left, guilloché ring right with "17 de 30 días" in its centre; ring fill = spend vs last month at same scale. Below: "Por cuenta" rows with note-hue chip, name, one status line, amount. Bottom tab bar: Mes · Egresos · + (raised purple/ink circle) · Deudas · Más.

FORM: Billete (Colombian banknotes), position 1 on my ordered list (IMPECCABLE'S PICK, chosen over the roll). seed:fbe413b506bae435. Signature interaction: the guilloché month ring fills with spend pace; Reduce Motion shows it static.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

Open decisions: logo kept or redrawn (user deferred to the end).
