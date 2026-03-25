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
      icon: Icons.dashboard_rounded,
      title: 'Tu resumen en un vistazo',
      body: 'Revisa la deuda total, el uso por tarjeta y compara mes a mes desde el Dashboard.',
    ),
    _OnboardingSlide(
      icon: Icons.credit_card_rounded,
      title: 'Tarjetas y egresos',
      body: 'Registra tus gastos por tarjeta o medio de pago. Filtra por fecha y mantén todo ordenado.',
    ),
    _OnboardingSlide(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Deudas a cuotas',
      body: 'Lleva tus deudas con cuotas, registra pagos y sigue el avance. Todo se sincroniza en la nube.',
    ),
  ];

  Future<void> _complete() async {
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: Theme.of(context).brightness == Brightness.dark
            ? null
            : const BoxDecoration(gradient: AppThemeColors.backgroundGradientLight),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _complete,
                  child: Text(
                    'Omitir',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (context, i) => _SlidePage(slide: _slides[i], isDark: isDark),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Row(
                  children: [
                    ...List.generate(
                      _slides.length,
                      (i) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: i == _currentPage
                              ? AppThemeColors.primaryGreen
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        if (_currentPage == _slides.length - 1) {
                          _complete();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      icon: Icon(
                        _currentPage == _slides.length - 1 ? Icons.check : Icons.arrow_forward,
                        size: 20,
                      ),
                      label: Text(
                        _currentPage == _slides.length - 1 ? 'Comenzar' : 'Siguiente',
                      ),
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
  const _SlidePage({required this.slide, required this.isDark});

  final _OnboardingSlide slide;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 72,
              color: AppThemeColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
