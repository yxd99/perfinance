import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/inset_add_row.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_card_detail_screen.dart';
import 'package:perfinance/features/credit_cards/credit_card_form_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/db_helper.dart';

CreditCard _card(String id, String alias, {bool isActive = true}) => CreditCard(
      id: id,
      userId: 'u1',
      alias: alias,
      cutOffDay: 12,
      managementFee: 15000,
      isActive: isActive,
    );

Widget _app(List<CreditCard> cards, {dynamic db}) {
  return ProviderScope(
    overrides: [
      creditCardsListProvider.overrideWith((ref) async => cards),
      accountHueSlotsProvider.overrideWith((ref) async => {for (var i = 0; i < cards.length; i++) cards[i].id: i}),
      if (db != null) ...[
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        cardPaymentRepositoryProvider.overrideWithValue(CardPaymentRepository(null, dbOverride: db)),
        minPaymentConfigRepositoryProvider.overrideWithValue(MinPaymentConfigRepository(null, dbOverride: db)),
      ],
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

    // Alta como última fila del grupo de tarjetas, sin textos de ayuda de gestos.
    expect(find.widgetWithText(InsetAddRow, 'Agregar tarjeta'), findsOneWidget);
    expect(find.textContaining('Mantén presionada'), findsNothing);
  });

  testWidgets('tocar una tarjeta abre su detalle, que trae la acción Editar', (tester) async {
    final db = await tester.runAsync(() => openTestDatabase());
    addTearDown(() => tester.runAsync(() async => db.close()));
    await tester.pumpWidget(_app([_card('c1', 'Visa')], db: db));
    await tester.pumpAndSettle();

    // El detalle lee SQLite real: se deja correr la base y se avanzan los
    // cuadros a mano (los indicadores de carga no dejan asentar la animación).
    await tester.tap(find.text('Visa'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CreditCardDetailScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Editar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CreditCardFormScreen), findsOneWidget);
    expect(find.text('Editar tarjeta'), findsOneWidget);
  });

  testWidgets('deslizar a la izquierda pide confirmar el borrado; mantener presionado no hace nada', (tester) async {
    await tester.pumpWidget(_app([_card('c1', 'Visa')]));
    await tester.pumpAndSettle();

    // Mantener presionado no tiene un significado oculto.
    final inkWell = tester.widget<InkWell>(find.ancestor(of: find.text('Visa'), matching: find.byType(InkWell)).first);
    expect(inkWell.onLongPress, isNull);

    expect(find.byType(Dismissible), findsOneWidget);
    await tester.drag(find.text('Visa'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar tarjeta'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Visa'), findsOneWidget);
  });

  testWidgets('sin tarjetas muestra un estado vacío con acción', (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no tienes tarjetas.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Agregar tarjeta'), findsOneWidget);
  });
}
