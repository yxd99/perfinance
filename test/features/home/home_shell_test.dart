import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/home/home_tab_bar.dart';
import 'package:perfinance/features/auth/account_service.dart';
import 'package:perfinance/features/more/more_screen.dart';
import 'package:perfinance/services/sync_service.dart';

class _FakeHideValues extends HideValuesNotifier {
  @override
  Future<bool> build() async => false;
}

Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
    );

void main() {
  group('HomeTabBar', () {
    testWidgets('muestra las cuatro secciones y el «+» accesible', (tester) async {
      var added = 0;
      final selected = <int>[];
      await tester.pumpWidget(_app(HomeTabBar(
        currentIndex: 0,
        onSelect: selected.add,
        onAdd: () => added++,
      )));

      for (final label in ['Mes', 'Egresos', 'Deudas', 'Más']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      await tester.tap(find.bySemanticsLabel('Registrar egreso'));
      await tester.tap(find.bySemanticsLabel('Deudas'));
      expect(added, 1);
      // El botón dice qué hace: «Egreso», no un «+» suelto.
      expect(find.text('Egreso'), findsOneWidget);
      expect(selected, [2]);
      expect(tester.getSize(find.bySemanticsLabel('Registrar egreso')).height, greaterThanOrEqualTo(44));
    });

    testWidgets('marca en «Más» los cambios sin subir', (tester) async {
      await tester.pumpWidget(_app(HomeTabBar(
        currentIndex: 0,
        pendingCount: 3,
        onSelect: (_) {},
        onAdd: () {},
      )));
      expect(find.bySemanticsLabel('Más, 3 cambios sin subir'), findsOneWidget);
    });
  });

  group('MoreScreen', () {
    final overrides = <Override>[
      hideValuesProvider.overrideWith(_FakeHideValues.new),
      pendingChangesCountProvider.overrideWith((ref) async => 2),
      accountInfoProvider.overrideWith((ref) => const AccountInfo(email: 'ana@gmail.com', name: 'Ana')),
    ];

    testWidgets('lista las secciones, los ajustes y cerrar sesión', (tester) async {
      await tester.pumpWidget(_app(const MoreScreen(), overrides: overrides));
      await tester.pumpAndSettle();

      for (final label in [
        'Tu cuenta',
        'Tarjetas de crédito',
        'Cuentas de ahorro',
        'Débito, Nequi y efectivo',
        'Me deben',
        'Auto-pagos',
        'Registro con Apple Wallet',
        'Guía de la app',
        'Ocultar valores',
        'Sincronizar ahora',
        '2 cambios sin subir',
      ]) {
        // Con subtítulos la lista ya no entra entera: se baja hasta cada fila.
        await tester.scrollUntilVisible(find.text(label), 100);
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.scrollUntilVisible(find.text('Cerrar sesión'), 100);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      // El asesor con IA está deshabilitado (advisorEnabled = false).
      expect(find.text('Asesor financiero'), findsNothing);
      // "Tu cuenta" muestra el nombre de la cuenta como subtítulo.
      await tester.scrollUntilVisible(find.text('Tu cuenta'), -100);
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('«Cerrar sesión» termina por encima de la barra inferior', (tester) async {
      // iPhone 15: 393×852 pt con el indicador de inicio (34 pt) abajo.
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: const SafeArea(bottom: false, child: MoreScreen()),
            bottomNavigationBar: HomeTabBar(currentIndex: 3, onSelect: (_) {}, onAdd: () {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(CustomScrollView), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      final logoutBottom = tester.getBottomLeft(find.widgetWithText(ListTile, 'Cerrar sesión')).dy;
      final tabBarTop = tester.getTopLeft(find.byType(HomeTabBar)).dy;
      expect(logoutBottom, lessThanOrEqualTo(tabBarTop - 16));
    });

    testWidgets('sin barra inferior deja aire sobre el indicador de inicio', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const MoreScreen(), overrides: overrides));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(CustomScrollView), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      final logoutBottom = tester.getBottomLeft(find.widgetWithText(ListTile, 'Cerrar sesión')).dy;
      expect(logoutBottom, lessThanOrEqualTo(852 - 34 - 24));
    });

    testWidgets('al sincronizar gira el ícono pero no el contador', (tester) async {
      await tester.pumpWidget(_app(
        const MoreScreen(),
        overrides: [...overrides, isSyncingProvider.overrideWith((ref) => true)],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 100));

      final badge = find.descendant(of: find.byType(SyncNowTile), matching: find.byType(Badge));
      expect(badge, findsOneWidget);
      expect(find.ancestor(of: badge, matching: find.byType(RotationTransition)), findsNothing);
      final rotation = find.descendant(of: find.byType(SyncNowTile), matching: find.byType(RotationTransition));
      expect(find.descendant(of: rotation, matching: find.byType(Icon)), findsOneWidget);
      expect(find.text('Sincronizando...'), findsOneWidget);
    });
  });
}
