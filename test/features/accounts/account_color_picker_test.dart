import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/accounts/account_color_picker.dart';

void main() {
  testWidgets('muestra los cinco colores, marca el elegido y avisa al tocar otro', (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AccountColorPicker(
            selected: picked ?? 0,
            onChanged: (v) => setState(() => picked = v),
          ),
        ),
      ),
    ));

    expect(find.text('Color'), findsOneWidget);
    for (final name in ['Verde', 'Azul', 'Naranja', 'Café', 'Rosado']) {
      final swatch = find.bySemanticsLabel(RegExp('^Color $name'));
      expect(swatch, findsOneWidget, reason: name);
      expect(tester.getSize(swatch).height, greaterThanOrEqualTo(44));
    }
    expect(tester.getSemantics(find.bySemanticsLabel(RegExp('^Color Verde'))), isSemantics(isSelected: true));

    await tester.tap(find.bySemanticsLabel(RegExp('^Color Café')));
    await tester.pump();
    expect(picked, 3);
    expect(tester.getSemantics(find.bySemanticsLabel(RegExp('^Color Café'))), isSemantics(isSelected: true));
  });
}
