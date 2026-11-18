import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_account_automatic_payments_screen.dart';
import 'package:perfinance/features/dashboard/dashboard_account_expenses_screen.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/dashboard/debt_summary_copy.dart';
import 'package:perfinance/features/dashboard/month_pace.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/services/dashboard_service.dart';

const double _gutter = 16;

String _money(num value, bool hide) => '\$${formatCurrencyDisplay(value, hide)}';

/// Pestaña «Mes»: el mes se lee como un billete. Primero cuánto salió y a qué ritmo,
/// después lo que pide atención, el gasto por cuenta y, debajo, deuda y detalle.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedDashboardMonthProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    final asyncExpenses = ref.watch(expensesListProvider);
    final cards = ref.watch(creditCardsListProvider).valueOrNull ?? const <CreditCard>[];
    final now = DateTime.now();

    final spend = asyncExpenses.whenData((list) => computeMonthSpend(list, selectedMonth, now));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expensesListProvider);
          ref.invalidate(expensePaymentDisplayProvider);
          ref.invalidate(creditCardsListProvider);
          ref.invalidate(dashboardDebtProvider);
          ref.invalidate(hasActiveDebtSourcesProvider);
          ref.invalidate(dashboardAutomaticPaymentsSummaryProvider);
          ref.invalidate(overdueAutomaticPaymentsProvider);
          ref.invalidate(dashboardUsageProvider);
          ref.invalidate(dashboardComparisonProvider);
          ref.invalidate(dashboardMinPaymentSummaryProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // 57pt arriba: el título cae a la misma altura que el título grande de
          // Egresos, Deudas y Más (SliverAppBar.large con barra de 44pt).
          padding: const EdgeInsets.fromLTRB(_gutter, _titleTop, _gutter, 40),
          children: [
            _MonthTitle(selected: selectedMonth, now: now),
            const SizedBox(height: 12),
            spend.when(
              data: (s) => _MonthNote(spend: s, hideValues: hideValues, isCurrentMonth: _isSameMonth(selectedMonth, now)),
              loading: () => const _MonthNoteLoading(),
              error: (_, _) => _SectionError(
                onRetry: () => ref.invalidate(expensesListProvider),
              ),
            ),
            _AttentionRows(hideValues: hideValues, month: selectedMonth),
            const _SectionHeader('Por cuenta'),
            spend.when(
              data: (s) => _AccountsGroup(spend: s, cards: cards, hideValues: hideValues, now: now),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => _SectionError(
                onRetry: () => ref.invalidate(expensesListProvider),
              ),
            ),
            _DebtSection(hideValues: hideValues),
            _MinPaymentSection(hideValues: hideValues, cards: cards, month: selectedMonth),
            _AutomaticPaymentsSection(hideValues: hideValues),
            _ComparisonSection(hideValues: hideValues, month: selectedMonth),
          ],
        ),
      ),
    );
  }
}

const double _titleTop = 57;

bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

// ---------------------------------------------------------------------------
// Título grande + selector de mes
// ---------------------------------------------------------------------------

class _MonthTitle extends ConsumerWidget {
  const _MonthTitle({required this.selected, required this.now});

  final DateTime selected;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final isCurrentMonth = _isSameMonth(selected, now);
    final title = selected.year == now.year
        ? monthNameEs(selected.month)
        : '${monthNameEs(selected.month)} ${selected.year}';

    void setMonth(DateTime m) => ref.read(selectedDashboardMonthProvider.notifier).state = m;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Elegir mes, $title',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year, now.month + 1),
                );
                if (picked != null) setMonth(DateTime(picked.year, picked.month, 1));
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c.ink),
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Mes anterior',
          icon: const Icon(CupertinoIcons.chevron_left),
          color: c.accent,
          onPressed: () => setMonth(DateTime(selected.year, selected.month - 1, 1)),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          icon: const Icon(CupertinoIcons.chevron_right),
          color: c.accent,
          onPressed: isCurrentMonth ? null : () => setMonth(DateTime(selected.year, selected.month + 1, 1)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Nota del mes (billete de 50.000)
// ---------------------------------------------------------------------------

const double _ringSize = 132;
const double _notePadding = 20;

class _MonthNote extends StatelessWidget {
  const _MonthNote({required this.spend, required this.hideValues, required this.isCurrentMonth});

  final MonthSpend spend;
  final bool hideValues;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final label = isCurrentMonth ? 'Gastado este mes' : 'Gastado en ${monthNameEs(spend.month.month).toLowerCase()}';
    final amount = _money(spend.total, hideValues);
    final pace = paceSentence(spend);
    final ring = ringLabel(spend);
    final dayLine = ringDayLine(spend);

    return Semantics(
      container: true,
      label: '$label: ${hideValues ? 'oculto' : amount}. $pace. ${ring.spoken}.${dayLine == null ? '' : ' $dayLine.'}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: c.heroGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _GuillochePainter(color: c.onHeroSoft),
          child: Padding(
            padding: const EdgeInsets.all(_notePadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: t.labelLarge?.copyWith(color: c.onHeroMuted)),
                      if (dayLine != null) ...[
                        const SizedBox(height: 2),
                        Text(dayLine, style: t.labelSmall?.copyWith(color: c.onHeroMuted, fontFeatures: kTabularFigures)),
                        const SizedBox(height: 46),
                      ] else
                        const SizedBox(height: 64),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(amount, maxLines: 1, style: t.displaySmall?.copyWith(color: c.onHero)),
                      ),
                      const SizedBox(height: 6),
                      Text(pace, style: t.bodySmall?.copyWith(color: c.onHeroMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _PaceRing(fraction: ringFraction(spend), label: ring),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthNoteLoading extends StatelessWidget {
  const _MonthNoteLoading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: _ringSize + _notePadding * 2,
      decoration: BoxDecoration(gradient: c.heroGradient, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.onHero),
      ),
    );
  }
}

/// Textura de líneas finas concéntricas, centrada en el anillo, solo dentro del billete.
class _GuillochePainter extends CustomPainter {
  _GuillochePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - _notePadding - _ringSize / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    // El interior del anillo queda limpio para leer el día.
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: center, radius: _ringSize / 2 + 6)),
    ));
    final maxR = math.sqrt(size.width * size.width + size.height * size.height);
    for (var r = _ringSize / 2 + 10; r < maxR; r += 7) {
      canvas.drawCircle(center, r, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GuillochePainter old) => old.color != color;
}

/// Anillo de ritmo: banda de roseta guilloché con un arco que se llena según lo
/// gastado contra el mes anterior. El centro dice esa misma métrica («85%» «de
/// octubre»); sin mes anterior, el día. Se anima una vez al cargar, salvo con Reducir movimiento.
class _PaceRing extends StatefulWidget {
  const _PaceRing({required this.fraction, required this.label});

  final double fraction;
  final RingLabel label;

  @override
  State<_PaceRing> createState() => _PaceRingState();
}

class _PaceRingState extends State<_PaceRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: _ringSize,
      height: _ringSize,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            fraction: widget.fraction * _progress.value,
            lineColor: c.onHeroSoft,
            fillColor: c.onHero,
          ),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label.value,
                style: t.headlineMedium?.copyWith(color: c.onHero, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
              ),
              Text(widget.label.caption, style: t.labelSmall?.copyWith(color: c.onHeroMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.lineColor, required this.fillColor});

  final double fraction;
  final Color lineColor;
  final Color fillColor;

  static const double _band = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - _band;
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // Roseta: círculos pequeños que giran sobre la pista, como el borde de un billete.
    const petals = 48;
    for (var i = 0; i < petals; i++) {
      final a = 2 * math.pi * i / petals;
      canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * radius, _band, line);
    }
    canvas.drawCircle(center, radius - _band, line);
    canvas.drawCircle(center, radius + _band, line);

    if (fraction <= 0) return;
    final arc = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.lineColor != lineColor || old.fillColor != fillColor;
}

// ---------------------------------------------------------------------------
// Atención
// ---------------------------------------------------------------------------

class _AttentionRows extends ConsumerWidget {
  const _AttentionRows({required this.hideValues, required this.month});

  final bool hideValues;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overdueAutomaticPaymentsProvider);
    final minSummary = ref.watch(dashboardMinPaymentSummaryProvider);

    final rows = <Widget>[
      ...overdue.when(
        data: (list) => [
          if (list.isNotEmpty)
            _AttentionRow(
              text: list.length == 1
                  ? 'Tenés 1 pago automático atrasado sin procesar'
                  : 'Tenés ${list.length} pagos automáticos atrasados sin procesar',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutomaticPaymentsScreen()),
              ),
            ),
        ],
        loading: () => const [],
        error: (_, _) => [
          _SectionError(
            onRetry: () => ref.invalidate(overdueAutomaticPaymentsProvider),
          ),
        ],
      ),
      ...minSummary.when(
        data: (s) => [
          if (s.totalPending > 0)
            _AttentionRow(
              text: 'Pago mínimo pendiente: ${_money(s.totalPending, hideValues)}',
              detail: s.pendingByCard.length == 1 ? 'En 1 tarjeta' : 'En ${s.pendingByCard.length} tarjetas',
            ),
        ],
        loading: () => const [],
        error: (_, _) => [
          _SectionError(
            onRetry: () => ref.invalidate(dashboardMinPaymentSummaryProvider),
          ),
        ],
      ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.text, this.detail, this.onTap});

  final String text;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.warningSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle, color: c.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text,
                        style: t.bodyMedium?.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                      if (detail != null) Text(detail!, style: t.bodySmall?.copyWith(color: c.warning)),
                    ],
                  ),
                ),
                if (onTap != null) Icon(CupertinoIcons.chevron_right, color: c.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Por cuenta
// ---------------------------------------------------------------------------

class _AccountsGroup extends ConsumerWidget {
  const _AccountsGroup({required this.spend, required this.cards, required this.hideValues, required this.now});

  final MonthSpend spend;
  final List<CreditCard> cards;
  final bool hideValues;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(expensePaymentDisplayProvider).valueOrNull;
    final monthName = monthNameEs(spend.month.month).toLowerCase();
    if (spend.byAccount.isEmpty) {
      return _Group(children: [_EmptyRow('Todavía no hay egresos en $monthName.')]);
    }
    final cardById = {for (final c in cards) c.id: c};
    final isCurrent = _isSameMonth(spend.month, now);

    return _Group(
      children: [
        for (final a in spend.byAccount)
          _AccountRow(
            id: a.paymentRef,
            name: a.isCreditCard
                ? (display?.cardAliases[a.paymentRef] ?? 'Tarjeta')
                : (display?.methodNames[a.paymentRef] ?? 'Medio de pago'),
            status: _statusFor(a, cardById[a.paymentRef], isCurrent),
            amount: _money(a.total, hideValues),
            onTap: () {
              final name = a.isCreditCard
                  ? (display?.cardAliases[a.paymentRef] ?? 'Tarjeta')
                  : (display?.methodNames[a.paymentRef] ?? 'Medio de pago');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardAccountExpensesScreen(
                    alias: name,
                    paymentType: a.paymentType,
                    paymentRef: a.paymentRef,
                    month: spend.month,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  String _statusFor(AccountSpend a, CreditCard? card, bool isCurrent) {
    if (isCurrent && card != null && card.isActive) {
      final cut = cutOffStatus(card.cutOffDay, now);
      if (cut != null) return cut;
    }
    return a.count == 1 ? '1 egreso' : '${a.count} egresos';
  }
}

// ---------------------------------------------------------------------------
// Debajo del pliegue
// ---------------------------------------------------------------------------

class _DebtSection extends ConsumerWidget {
  const _DebtSection({required this.hideValues});

  final bool hideValues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(hasActiveDebtSourcesProvider).when(
          data: (hasActive) {
            if (!hasActive) return const SizedBox.shrink();
            return ref.watch(dashboardDebtProvider).when(
                  data: (debt) => _DebtBody(debt: debt, hideValues: hideValues),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => _Section(
                    title: 'Deuda',
                    child: _SectionError(
                      onRetry: () => ref.invalidate(dashboardDebtProvider),
                    ),
                  ),
                );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => _Section(
            title: 'Deuda',
            child: _SectionError(
              onRetry: () => ref.invalidate(hasActiveDebtSourcesProvider),
            ),
          ),
        );
  }
}

class _DebtBody extends StatelessWidget {
  const _DebtBody({required this.debt, required this.hideValues});

  final DebtBreakdown debt;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final parts = debtTotalParts(debt, hideValues: hideValues);
    return _Section(
      title: 'Deuda',
      child: _Group(
        children: [
          Semantics(
            container: true,
            label: 'Deuda total: ${hideValues ? 'oculta' : _money(debt.total, false)}'
                '${parts == null || hideValues ? '' : '. ${debtTotalParts(debt, hideValues: false)}'}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Deuda total', style: t.bodyLarge?.copyWith(color: c.ink)),
                        if (parts != null) ...[
                          const SizedBox(height: 2),
                          Text(parts, style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _money(debt.total, hideValues),
                        style: t.headlineSmall?.copyWith(
                          // Lo que se debe va en tinta: el rojo queda para lo vencido.
                          color: c.ink,
                          fontWeight: FontWeight.w800,
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final item in debt.items)
            _PlainRow(
              title: item.label,
              status: item.isCreditCard ? 'Tarjeta de crédito' : 'Deuda',
              amount: _money(item.balance, hideValues),
            ),
        ],
      ),
    );
  }
}

class _MinPaymentSection extends ConsumerWidget {
  const _MinPaymentSection({required this.hideValues, required this.cards, required this.month});

  final bool hideValues;
  final List<CreditCard> cards;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Los errores de este provider ya se muestran en la fila de atención.
    final summary = ref.watch(dashboardMinPaymentSummaryProvider).valueOrNull;
    if (summary == null || summary.totalPending <= 0) return const SizedBox.shrink();
    final alias = {for (final c in cards) c.id: c.alias};
    return _Section(
      title: 'Pago mínimo de ${monthNameEs(month.month).toLowerCase()}',
      child: _Group(
        children: [
          _PlainRow(title: 'Total pendiente', amount: _money(summary.totalPending, hideValues), strong: true),
          for (final e in summary.pendingByCard.entries)
            _AccountRow(
              id: e.key,
              name: alias[e.key] ?? 'Tarjeta',
              status: 'Pendiente',
              amount: _money(e.value, hideValues),
            ),
        ],
      ),
    );
  }
}

class _AutomaticPaymentsSection extends ConsumerWidget {
  const _AutomaticPaymentsSection({required this.hideValues});

  final bool hideValues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(dashboardAutomaticPaymentsSummaryProvider).when(
          data: (summary) {
            if (summary.byAccount.isEmpty) return const SizedBox.shrink();
            return _Section(
              title: 'Pagos automáticos del mes',
              child: _Group(
                children: [
                  _PlainRow(title: 'Total estimado', amount: _money(summary.totalPerMonth, hideValues), strong: true),
                  for (final a in summary.byAccount)
                    _AccountRow(
                      id: a.paymentRef,
                      name: a.alias,
                      status: a.isCreditCard ? 'Tarjeta de crédito' : 'Medio de pago',
                      amount: _money(a.amount, hideValues),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DashboardAccountAutomaticPaymentsScreen(
                            alias: a.alias,
                            paymentType: a.paymentType,
                            paymentRef: a.paymentRef,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => _Section(
            title: 'Pagos automáticos del mes',
            child: _SectionError(
              onRetry: () => ref.invalidate(dashboardAutomaticPaymentsSummaryProvider),
            ),
          ),
        );
  }
}

class _ComparisonSection extends ConsumerWidget {
  const _ComparisonSection({required this.hideValues, required this.month});

  final bool hideValues;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prevName = monthNameEs(DateTime(month.year, month.month - 1, 1).month).toLowerCase();
    final title = 'Tarjetas contra $prevName';
    return ref.watch(dashboardComparisonProvider).when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return _Section(
              title: title,
              child: _Group(
                children: [
                  for (final cmp in list)
                    _AccountRow(
                      id: cmp.cardId,
                      name: cmp.alias,
                      status: 'Este mes ${_money(cmp.thisMonth, hideValues)} · $prevName ${_money(cmp.lastMonth, hideValues)}',
                      trailing: _DeltaLabel(comparison: cmp),
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => _Section(
            title: title,
            child: _SectionError(
              onRetry: () => ref.invalidate(dashboardComparisonProvider),
            ),
          ),
        );
  }
}

class _DeltaLabel extends StatelessWidget {
  const _DeltaLabel({required this.comparison});

  final CardComparison comparison;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final pct = comparison.percentChange;
    final String text;
    final Color color;
    if (pct == null) {
      // Sin gasto el mes anterior no hay porcentaje que mostrar.
      text = comparison.thisMonth > 0 ? 'Nuevo' : '=';
      color = c.textMuted;
    } else if (pct.round() == 0) {
      text = '=';
      color = c.textMuted;
    } else if (comparison.isIncrease) {
      text = '+${pct.round()}%';
      color = c.danger;
    } else {
      text = '−${pct.round()}%';
      color = c.positive;
    }
    return Text(
      text,
      style: t.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas compartidas: secciones agrupadas, filas, error
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: t.labelMedium?.copyWith(color: c.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_SectionHeader(title), child],
    );
  }
}

/// Lista agrupada al estilo iOS: filas sobre `surface` con separadores finos.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, indent: 16, color: c.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Fila de cuenta: ficha con el tono del billete, nombre, una línea de estado y monto.
class _AccountRow extends ConsumerWidget {
  const _AccountRow({
    required this.id,
    required this.name,
    required this.status,
    this.amount,
    this.trailing,
    this.onTap,
  });

  final String id;
  final String name;
  final String status;
  final String? amount;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 22,
                decoration: BoxDecoration(
                  color: ref.accountHue(context, id),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge?.copyWith(color: c.ink)),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (amount != null)
                Text(
                  amount!,
                  style: t.titleSmall?.copyWith(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.title, required this.amount, this.status, this.strong = false});

  final String title;
  final String? status;
  final String amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(color: c.ink, fontWeight: strong ? FontWeight.w600 : null),
                  ),
                  if (status != null) Text(status!, style: t.bodySmall?.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: t.titleSmall?.copyWith(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textMuted)),
    );
  }
}

/// Error compacto de una sección. No se reporta acá: `ErrorReporterProviderObserver`
/// ya manda a Sentry todo provider que falla.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Icon(CupertinoIcons.exclamationmark_circle, size: 20, color: c.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text('No pudimos cargar esta sección', style: t.bodyMedium?.copyWith(color: c.ink)),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: c.accent),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
