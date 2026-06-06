import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Minimal fake Supabase client ─────────────────────────────────────────────

class _FakeFunctions extends FunctionsClient {
  _FakeFunctions() : super('', {});

  String? lastInvokedFunction;
  Object? lastBody;
  bool shouldThrow = false;
  int throwStatus = 500;
  Map<String, dynamic>? throwDetails;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
  }) async {
    lastInvokedFunction = functionName;
    lastBody = body;
    if (shouldThrow) {
      throw FunctionException(
        status: throwStatus,
        details: throwDetails,
      );
    }
    return FunctionResponse(data: {'ok': true}, status: 200);
  }
}

class _FakeAuth extends GoTrueClient {
  _FakeAuth() : super(url: 'http://localhost', headers: {});

  @override
  Session? get currentSession => _FakeSession();
}

class _FakeSession implements Session {
  @override
  String get accessToken => 'fake-token';
  @override
  bool get isExpired => false;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakeSupabaseClient implements SupabaseClient {
  _FakeSupabaseClient({required this.functions, required this.auth});

  @override
  final _FakeFunctions functions;
  @override
  final _FakeAuth auth;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeFunctions fakeFunctions;
  late ReceivableNotificationService service;

  ReceivableNotificationPayload _payload({
    ReceivableNotificationEvent event = ReceivableNotificationEvent.created,
    String recipientEmail = 'debtor@example.com',
    double? paymentAmount,
    DateTime? paymentDate,
  }) =>
      ReceivableNotificationPayload(
        event: event,
        recipientEmail: recipientEmail,
        debtorName: 'Juan Pérez',
        totalAmount: 400000,
        remainingBalance: 300000,
        paymentAmount: paymentAmount,
        paymentDate: paymentDate,
      );

  setUp(() {
    fakeFunctions = _FakeFunctions();
    final fakeClient = _FakeSupabaseClient(
      functions: fakeFunctions,
      auth: _FakeAuth(),
    );
    service = ReceivableNotificationService(
      fakeClient as SupabaseClient,
      isConfiguredOverride: true,
    );
  });

  group('notify no-op', () {
    test('does nothing when recipientEmail is empty', () async {
      await service.notify(_payload(recipientEmail: ''));
      expect(fakeFunctions.lastInvokedFunction, isNull);
    });

    test('does nothing when recipientEmail is whitespace', () async {
      await service.notify(_payload(recipientEmail: '   '));
      expect(fakeFunctions.lastInvokedFunction, isNull);
    });
  });

  Map<String, dynamic> _body() => fakeFunctions.lastBody! as Map<String, dynamic>;

  group('notify invokes correct function', () {
    test('calls send-receivable-notification', () async {
      await service.notify(_payload());
      expect(fakeFunctions.lastInvokedFunction, 'send-receivable-notification');
    });
  });

  group('notify payload: created event', () {
    test('sends event=created', () async {
      await service.notify(_payload(event: ReceivableNotificationEvent.created));
      expect(_body()['event'], 'created');
    });

    test('includes recipientEmail, debtorName, totalAmount, remainingBalance', () async {
      await service.notify(_payload());
      final body = _body();
      expect(body['recipientEmail'], 'debtor@example.com');
      expect(body['debtorName'], 'Juan Pérez');
      expect(body['totalAmount'], 400000);
      expect(body['remainingBalance'], 300000);
    });

    test('does not include paymentAmount when null', () async {
      await service.notify(_payload());
      expect(_body().containsKey('paymentAmount'), isFalse);
    });
  });

  group('notify payload: payment events', () {
    test('sends event=payment_recorded with amount and date', () async {
      final date = DateTime(2026, 6, 4);
      await service.notify(_payload(
        event: ReceivableNotificationEvent.paymentRecorded,
        paymentAmount: 100000,
        paymentDate: date,
      ));
      final body = _body();
      expect(body['event'], 'payment_recorded');
      expect(body['paymentAmount'], 100000);
      expect(body.containsKey('paymentDate'), isTrue);
    });

    test('sends event=payment_edited', () async {
      await service.notify(_payload(
        event: ReceivableNotificationEvent.paymentEdited,
        paymentAmount: 150000,
        paymentDate: DateTime(2026, 5, 1),
      ));
      expect(_body()['event'], 'payment_edited');
    });

    test('sends event=payment_deleted', () async {
      await service.notify(_payload(
        event: ReceivableNotificationEvent.paymentDeleted,
        paymentAmount: 50000,
        paymentDate: DateTime(2026, 4, 15),
      ));
      expect(_body()['event'], 'payment_deleted');
    });
  });

  group('notify error handling', () {
    test('throws when function raises FunctionException', () async {
      fakeFunctions.shouldThrow = true;
      fakeFunctions.throwStatus = 500;
      fakeFunctions.throwDetails = {'error': 'Internal error'};

      await expectLater(
        () => service.notify(_payload()),
        throwsException,
      );
    });
  });
}
