import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/repositories/chat_conversation_repository.dart';
import 'package:perfinance/features/chat/chat_provider.dart';
import 'package:perfinance/features/chat/chat_screen.dart';
import 'package:perfinance/services/financial_advisor_service.dart';

class _FakeService implements ChatAIService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRepo implements ChatConversationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Notifier sin red ni Supabase: no carga conversaciones.
class _FakeChat extends ChatNotifier {
  _FakeChat() : super(_FakeService(), _FakeRepo());

  @override
  Future<void> loadConversations() async {}
}

Widget _app({required bool pushed}) => ProviderScope(
      overrides: [chatProvider.overrideWith((ref) => _FakeChat())],
      child: MaterialApp(
        theme: AppTheme.light,
        home: pushed
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen())),
                      child: const Text('Abrir asesor'),
                    ),
                  ),
                ),
              )
            : const ChatScreen(),
      ),
    );

void main() {
  testWidgets('abierto desde otra pantalla muestra «atrás», no la hamburguesa', (tester) async {
    await tester.pumpWidget(_app(pushed: true));
    await tester.tap(find.text('Abrir asesor'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(DrawerButton), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Abrir asesor'), findsOneWidget);
  });

  testWidgets('el historial se abre desde el ícono de lista del compositor', (tester) async {
    await tester.pumpWidget(_app(pushed: false));
    await tester.pumpAndSettle();

    expect(find.byType(DrawerButton), findsNothing);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.list_bullet));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Conversaciones'), findsOneWidget);
  });
}
