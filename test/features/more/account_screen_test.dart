import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/auth/account_service.dart';
import 'package:perfinance/features/more/account_screen.dart';
import 'package:perfinance/features/more/email_quota.dart';

class _FakeAccountService implements AccountService {
  String? savedName;
  String? changedFrom;
  String? changedTo;
  Object? changeError;

  @override
  Future<void> updateName(String name) async => savedName = name;

  @override
  Future<void> changePassword({required String current, required String next}) async {
    if (changeError != null) throw changeError!;
    changedFrom = current;
    changedTo = next;
  }
}

void main() {
  late _FakeAccountService service;

  Widget app() => ProviderScope(
        overrides: [
          accountInfoProvider.overrideWith((ref) => const AccountInfo(email: 'ana@gmail.com', name: 'Ana')),
          accountServiceProvider.overrideWithValue(service),
          emailQuotaProvider.overrideWith((ref) async => const EmailQuota(sent: 3, quota: 10)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AccountScreen()),
      );

  setUp(() => service = _FakeAccountService());

  testWidgets('muestra nombre, correo y correos del mes', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Ana'), findsOneWidget);
    expect(find.text('ana@gmail.com'), findsOneWidget);
    expect(find.textContaining('Te quedan 7 de 10'), findsOneWidget);
  });

  testWidgets('guarda el nombre sin espacios a los lados', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana'), '  Ana Pérez  ');
    await tester.tap(find.text('Guardar nombre'));
    await tester.pumpAndSettle();
    expect(service.savedName, 'Ana Pérez');
    expect(find.text('Nombre guardado.'), findsOneWidget);
  });

  testWidgets('cambiar contraseña valida antes de llamar al servidor', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña actual'), 'vieja1234');
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña nueva'), 'nueva1234');
    await tester.enterText(find.widgetWithText(TextField, 'Confirma la contraseña nueva'), 'otra12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
    await tester.pumpAndSettle();
    expect(find.text('Las contraseñas nuevas no coinciden.'), findsOneWidget);
    expect(service.changedTo, isNull);
  });

  testWidgets('cambiar contraseña con datos válidos llama al servicio', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña actual'), 'vieja1234');
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña nueva'), 'nueva1234');
    await tester.enterText(find.widgetWithText(TextField, 'Confirma la contraseña nueva'), 'nueva1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
    await tester.pumpAndSettle();
    expect(service.changedFrom, 'vieja1234');
    expect(service.changedTo, 'nueva1234');
    expect(find.text('Contraseña actualizada.'), findsOneWidget);
  });

  testWidgets('si la contraseña actual es incorrecta lo dice', (tester) async {
    service.changeError = const WrongCurrentPasswordException();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña actual'), 'mala12345');
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña nueva'), 'nueva1234');
    await tester.enterText(find.widgetWithText(TextField, 'Confirma la contraseña nueva'), 'nueva1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
  });
}
