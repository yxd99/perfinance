import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:perfinance/features/auth/account_deletion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeFunctions extends FunctionsClient {
  _FakeFunctions() : super('', {});

  String? lastInvokedFunction;
  Object? responseData = {'ok': true};
  FunctionException? error;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
    Future<void>? abortSignal,
  }) async {
    lastInvokedFunction = functionName;
    if (error != null) throw error!;
    return FunctionResponse(data: responseData, status: 200);
  }
}

class _FakeSupabaseClient implements SupabaseClient {
  _FakeSupabaseClient(this.functions);

  @override
  final _FakeFunctions functions;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  late _FakeFunctions functions;
  late AccountDeletionService service;

  setUp(() {
    functions = _FakeFunctions();
    service = AccountDeletionService(_FakeSupabaseClient(functions) as SupabaseClient);
  });

  test('llama a la función delete-account', () async {
    await service.deleteAccount();
    expect(functions.lastInvokedFunction, 'delete-account');
  });

  test('falla si la función no confirma el borrado', () async {
    functions.responseData = {'ok': false, 'error': 'Could not delete account'};
    await expectLater(service.deleteAccount(), throwsException);
  });

  test('falla si la función responde con error HTTP', () async {
    functions.error = FunctionException(status: 500, details: {'error': 'boom'});
    await expectLater(service.deleteAccount(), throwsException);
  });
}
