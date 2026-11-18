import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/row_actions_button.dart';

Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.android}) => MaterialApp(
      theme: AppTheme.light.copyWith(platform: platform),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('a la vista: abre las acciones y corre la elegida ($platform)', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_app(
        RowActionsButton(
          title: 'Nequi',
          actions: [
            RowAction(label: 'Editar', onSelected: () => calls.add('edit')),
            RowAction(label: 'Eliminar', destructive: true, onSelected: () => calls.add('delete')),
          ],
        ),
        platform: platform,
      ));

      final button = find.bySemanticsLabel('Acciones de Nequi');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(calls, ['delete']);
      // La hoja se cierra antes de correr la acción.
      expect(find.text('Editar'), findsNothing);
    });

    testWidgets('cancelar no corre nada ($platform)', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_app(
        RowActionsButton(title: 'Nequi', actions: [RowAction(label: 'Editar', onSelected: () => calls.add('edit'))]),
        platform: platform,
      ));
      await tester.tap(find.bySemanticsLabel('Acciones de Nequi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });
  }
}
