import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/onboarding_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/credit_cards/credit_card_form_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/savings/payment_method_form_screen.dart';
import 'package:perfinance/features/savings/savings_provider.dart';

/// Un paso de la guía: qué es la sección, dónde está y qué se hace ahí.
class _Step {
  const _Step({required this.icon, required this.title, required this.body, this.points = const []});

  final IconData icon;
  final String title;
  final String body;
  final List<String> points;
}

/// La guía recorre cada sección de la app; el último paso arma las cuentas.
const _steps = <_Step>[
  _Step(
    icon: CupertinoIcons.hand_raised,
    title: 'Hola, esto es Perfinance',
    body: 'Te ayuda a saber en qué se te va el dinero: cada egreso, tus tarjetas de crédito, '
        'tus deudas y lo que te deben. En un par de minutos te mostramos todo.',
    points: [
      'Registra egresos, lo que sale de tu bolsillo; no ingresos.',
      'Funciona sin conexión: todo se guarda en tu teléfono y se respalda en la nube cuando hay red.',
      'Puedes volver a ver esta guía cuando quieras en Más › Guía de la app.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.chart_pie,
    title: 'Mes: cómo vas este mes',
    body: 'La primera pestaña de abajo responde una sola pregunta: ¿voy bien este mes o me estoy pasando?',
    points: [
      'El billete morado muestra cuánto llevas gastado en el mes.',
      'El anillo compara tu ritmo con lo que habías gastado el mes pasado a esta misma altura.',
      'Debajo ves cuánto gastaste con cada cuenta y los avisos de corte de tus tarjetas.',
      'Toca el nombre del mes para mirar meses anteriores.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.plus_circle,
    title: 'Registra un egreso',
    body: 'El botón morado «+ Egreso», en el centro de la barra de abajo, está siempre a mano en cualquier pestaña.',
    points: [
      'Escribe el monto, elige con qué pagaste y, si quieres, agrega una descripción.',
      'La fecha es hoy; tócala para cambiarla.',
      'La app recuerda la última cuenta que usaste, así que casi siempre es monto y guardar.',
      'Si tienes muchas tarjetas o cuentas, búscalas por nombre al elegir.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.square_list,
    title: 'Egresos: todo lo que gastaste',
    body: 'La segunda pestaña tiene la lista completa, agrupada por día.',
    points: [
      'Filtra por fecha (Hoy, Ayer u Otra fecha) y por cuenta.',
      'Toca un egreso para editarlo.',
      'El botón de acciones (⋯) de cada fila tiene Editar y Eliminar a la vista.',
      'Deslizar una fila a la izquierda es un atajo para eliminarla.',
      'Puedes exportar tus egresos por correo.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.creditcard,
    title: 'Tarjetas de crédito',
    body: 'Las cargas en Más › Tarjetas de crédito. La deuda de cada una se calcula sola con tus egresos y pagos.',
    points: [
      'Pon un alias que reconozcas, el día de corte y la cuota de manejo.',
      'Configura el pago mínimo de cada mes y registra los pagos que le haces.',
      'Antes del corte, el Mes te avisa.',
      'Si dejas de usar una, desactívala: no se borra su historial.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.briefcase,
    title: 'Cuentas de ahorro',
    body: 'Es el dinero con el que pagas sin tarjeta de crédito: tu cuenta de ahorros o débito, Nequi, '
        'Daviplata o el efectivo.',
    points: [
      'Las cargas en Más › Cuentas de ahorro.',
      'Lo que pagas desde aquí no suma a la deuda de tus tarjetas.',
      'Cada cuenta y tarjeta tiene un color propio para reconocerla de un vistazo.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.money_dollar_circle,
    title: 'Deudas: lo que debes',
    body: 'La pestaña Deudas lleva tus préstamos y cuotas: cuánto debes y cuánto te falta.',
    points: [
      'Toca «Nueva deuda», junto al título, para agregar una.',
      'Entra a una deuda para registrar pagos y ver lo que falta.',
      'Con el botón de acciones (⋯) la marcas como pagada o la editas.',
      'Filtra entre Activas, Pagadas, Todas y Ocultas, o búscala por nombre.',
      'Las vencidas aparecen en rojo y lo dicen.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.person_2,
    title: 'Me deben: lo que prestaste',
    body: 'En Más › Me deben anotas el dinero que le prestaste a alguien.',
    points: [
      'Registra a quién, cuánto y los cobros que te va haciendo.',
      'Cuando te pague todo, márcala como cobrada.',
      'Si esa persona también usa Perfinance, le aparece la deuda en su app, solo para leer.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.repeat,
    title: 'Auto-pagos',
    body: 'En Más › Auto-pagos cargas lo que pagas todos los meses: arriendo, plan del celular, suscripciones.',
    points: [
      'Cada mes la app registra el egreso sola, en el día que elegiste.',
      'Así tu mes muestra el gasto real sin que tengas que acordarte.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.chat_bubble_2,
    title: 'Asesor, privacidad y respaldo',
    body: 'En Más encuentras también:',
    points: [
      'Asesor financiero: un chat que conoce tus números y te da ideas para gastar mejor.',
      'Ocultar valores: tapa los montos cuando estás mostrando la pantalla.',
      'Sincronizar ahora: sube tus cambios a la nube. El número rojo en Más dice cuántos faltan.',
      'En iPhone, con Apple Wallet se registran solos los pagos con tarjeta, sin abrir la app.',
    ],
  ),
  _Step(
    icon: CupertinoIcons.checkmark_seal,
    title: 'Empieza por tus cuentas',
    body: 'Para registrar un egreso necesitas al menos una tarjeta de crédito o una cuenta de ahorro. '
        'Puedes cargarlas ahora o después desde Más.',
  ),
];

/// Guía de la app. La primera vez se muestra tras iniciar sesión; desde
/// «Más › Guía de la app» se abre con [replay] y al terminar solo se cierra.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false, this.initialStep = 0});

  /// Abierta desde «Más»: «Cerrar» en vez de «Omitir», y no marca nada.
  final bool replay;

  /// Paso inicial (para tests y para retomar).
  final int initialStep;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController = PageController(initialPage: widget.initialStep);
  late int _currentPage = widget.initialStep;

  bool get _isLast => _currentPage == _steps.length - 1;

  Future<void> _finish() async {
    if (widget.replay) {
      Navigator.of(context).pop();
      return;
    }
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final total = _steps.length;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Paso ${_currentPage + 1} de $total',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (_currentPage + 1) / total,
                                minHeight: 4,
                                backgroundColor: c.track,
                                valueColor: AlwaysStoppedAnimation(c.accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_currentPage + 1} de $total',
                            style: t.labelSmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: c.textMuted),
                    child: Text(widget.replay ? 'Cerrar' : 'Omitir'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: total,
                itemBuilder: (context, i) => _StepPage(
                  step: _steps[i],
                  extra: i == total - 1 ? const _AccountsSetup() : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (_currentPage > 0) ...[
                    TextButton(
                      onPressed: () => _goTo(_currentPage - 1),
                      style: TextButton.styleFrom(minimumSize: const Size(44, 48), foregroundColor: c.accent),
                      child: const Text('Atrás'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLast ? _finish : () => _goTo(_currentPage + 1),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: Text(
                        _isLast ? (widget.replay ? 'Listo' : 'Empezar a usar Perfinance') : 'Siguiente',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, this.extra});

  final _Step step;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(step.icon, size: 40, color: c.accent)),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(step.title, style: t.headlineSmall?.copyWith(color: c.ink)),
          ),
          const SizedBox(height: 12),
          Text(step.body, style: t.bodyLarge?.copyWith(color: c.textMuted)),
          if (step.points.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final p in step.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ExcludeSemantics(
                        child: Icon(CupertinoIcons.checkmark_alt, size: 18, color: c.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p, style: t.bodyLarge?.copyWith(color: c.ink))),
                  ],
                ),
              ),
          ],
          if (extra != null) ...[const SizedBox(height: 24), extra!],
        ],
      ),
    );
  }
}

/// Último paso: crear la primera tarjeta o cuenta sin salir de la guía.
class _AccountsSetup extends ConsumerWidget {
  const _AccountsSetup();

  static String _cardsLabel(int n) => switch (n) {
        0 => 'Todavía no cargaste ninguna',
        1 => 'Tienes 1 tarjeta de crédito',
        _ => 'Tienes $n tarjetas de crédito',
      };

  static String _savingsLabel(int n) => switch (n) {
        0 => 'Todavía no cargaste ninguna',
        1 => 'Tienes 1 cuenta de ahorro',
        _ => 'Tienes $n cuentas de ahorro',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final cards = ref.watch(activeCreditCardsListProvider).valueOrNull?.length ?? 0;
    final savings = ref.watch(paymentMethodsListProvider).valueOrNull?.length ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: c.surface,
        child: Column(
          children: [
            _SetupRow(
              icon: CupertinoIcons.creditcard,
              label: 'Agregar tarjeta de crédito',
              status: _cardsLabel(cards),
              done: cards > 0,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CreditCardFormScreen()));
                ref.invalidate(creditCardsListProvider);
                ref.invalidate(activeCreditCardsListProvider);
              },
            ),
            Divider(height: 0.5, thickness: 0.5, indent: 56, color: c.divider),
            _SetupRow(
              icon: CupertinoIcons.briefcase,
              label: 'Agregar cuenta de ahorro',
              status: _savingsLabel(savings),
              done: savings > 0,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PaymentMethodFormScreen()));
                ref.invalidate(paymentMethodsListProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String status;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label. $status',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 24, color: c.accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: t.bodyLarge?.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(status, style: t.bodySmall?.copyWith(color: done ? c.positive : c.textMuted)),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.add, size: 20, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
