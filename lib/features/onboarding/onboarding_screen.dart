import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/onboarding_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: CupertinoIcons.calendar,
      title: 'Tu mes en un vistazo',
      body: 'En «Mes» ves cuánto llevás gastado, a qué ritmo vas contra el mes pasado y qué vence pronto.',
    ),
    _OnboardingSlide(
      icon: CupertinoIcons.plus_circle,
      title: 'Registrá en segundos',
      body: 'Tocá el «+» desde cualquier pestaña, escribí el monto y elegí la cuenta. Funciona sin conexión.',
    ),
    _OnboardingSlide(
      icon: CupertinoIcons.creditcard,
      title: 'Tarjetas y deudas a la vista',
      body: 'Llevá el corte de cada tarjeta, tus deudas y lo que te deben. Todo se respalda en la nube.',
    ),
  ];

  bool get _isLast => _currentPage == _slides.length - 1;

  Future<void> _complete() async {
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }

  void _next() {
    if (_isLast) {
      _complete();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(_currentPage + 1);
    } else {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: c.canvas,
      body: DecoratedBox(
        decoration: isDark
            ? BoxDecoration(color: c.canvas)
            : const BoxDecoration(gradient: AppThemeColors.backgroundGradientLight),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _complete,
                    style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: c.textMuted),
                    child: const Text('Omitir'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (context, i) => _SlidePage(slide: _slides[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Paso ${_currentPage + 1} de ${_slides.length}',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _slides.length; i++)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _currentPage ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: i == _currentPage ? c.accent : c.track,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: Text(_isLast ? 'Empezar' : 'Siguiente'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(child: Icon(slide.icon, size: 56, color: c.accent)),
            const SizedBox(height: 28),
            Semantics(
              header: true,
              child: Text(
                slide.title,
                textAlign: TextAlign.center,
                style: t.headlineSmall?.copyWith(color: c.ink),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              slide.body,
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
