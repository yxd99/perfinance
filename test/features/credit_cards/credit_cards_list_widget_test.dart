import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

CreditCard _card(String id, String alias, {bool isActive = true}) => CreditCard(
      id: id,
      userId: 'u1',
      alias: alias,
      cutOffDay: 12,
      managementFee: 15000,
      isActive: isActive,
    );

Widget _app(List<CreditCard> cards) {
  return ProviderScope(
    overrides: [
      creditCardsListProvider.overrideWith((ref) async => cards),
      accountHueSlotsProvider.overrideWith((ref) async => {for (var i = 0; i < cards.length; i++) cards[i].id: i}),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: CreditCardsScreen())),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cada tarjeta lleva su billete de color y la desactivada lo dice', (tester) async {
    await tester.pumpWidget(_app([
      _card('c1', 'Visa', isActive: false),
      _card('c2', 'Master'),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('card-hue-c1')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-hue-c2')), findsOneWidget);

    final c = AppTheme.light.extension<AppColors>()!;
    final activeChip = tester.widget<Container>(find.byKey(const ValueKey('card-hue-c2')));
    expect((activeChip.decoration! as BoxDecoration).color, c.accountColorFor('c2', const {'c1': 0, 'c2': 1}));

    expect(find.text(r'Desactivada · Corte el día 12 · Cuota $15.000'), findsOneWidget);
    expect(find.text(r'Corte el día 12 · Cuota $15.000'), findsOneWidget);

    // Activas primero.
    final masterY = tester.getTopLeft(find.text('Master')).dy;
    final visaY = tester.getTopLeft(find.text('Visa')).dy;
    expect(masterY, lessThan(visaY));

    expect(find.text('Agregar tarjeta'), findsOneWidget);
  });

  testWidgets('sin tarjetas muestra un estado vacío con acción', (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no tenés tarjetas.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Agregar tarjeta'), findsOneWidget);
  });
}
