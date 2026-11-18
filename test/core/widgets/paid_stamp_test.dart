import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';

void main() {
  testWidgets('sello muestra el texto en mayúsculas y lo anuncia normal', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: PaidStamp(label: 'Pagada'))),
    ));
    expect(find.text('PAGADA'), findsOneWidget);
    expect(find.bySemanticsLabel('Pagada'), findsOneWidget);
  });
}
