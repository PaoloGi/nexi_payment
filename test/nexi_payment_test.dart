import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexi_payment/nexi_payment.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NexiPayment (classic XPay)', () {
    const channel = MethodChannel('nexi_payment');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return 'OK';
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('xPayFrontOfficePaga initializes XPay and forwards the request',
        () async {
      final nexiPayment = NexiPayment(
        secretKey: 'secret',
        environment: EnvironmentUtils.TEST,
        domain: 'https://ecommerce.nexi.it',
      );

      final res = await nexiPayment.xPayFrontOfficePaga(
          'ALIAS', 'codTrans1', CurrencyUtilsQP.EUR, 2500);

      expect(res, 'OK');
      expect(log, hasLength(2));
      expect(log[0].method, 'initXPay');
      expect(log[0].arguments, {
        'secretKey': 'secret',
        'environment': 'TEST',
        'domain': 'https://ecommerce.nexi.it',
      });
      expect(log[1].method, 'xPayFrontOfficePaga');
      final args = Map<String, dynamic>.from(log[1].arguments as Map);
      expect(args['alias'], 'ALIAS');
      expect(args['codTrans'], 'codTrans1');
      expect(args['currency'], 'EUR');
      expect(args['amount'], 2500);

      // The channel arguments must not carry fields that neither native
      // implementation reads (and that `mac` misleadingly suggested were
      // computed client-side).
      expect(args.containsKey('timeStamp'), isFalse);
      expect(args.containsKey('mac'), isFalse);
      expect(args.containsKey('clientType'), isFalse);
      expect(args.containsKey('extraKeys'), isFalse);
      expect(args.keys,
          containsAll(<String>['alias', 'codTrans', 'currency', 'amount']));
    });

    test(
        'xPayFrontOfficePaga resolves with NexiPayment.canceledByUser when the user cancels',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        if (call.method == 'initXPay') return 'OK';
        return NexiPayment.canceledByUser;
      });

      final nexiPayment = NexiPayment(secretKey: 'secret');

      final res = await nexiPayment.xPayFrontOfficePaga(
          'ALIAS', 'codTrans1', CurrencyUtilsQP.EUR, 2500);

      expect(res, NexiPayment.canceledByUser);
      expect(res, 'Operation canceled by the user');
    });

    test(
        'xPayFrontOfficePaga rethrows a PlatformException raised by the native side',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        if (call.method == 'initXPay') return 'OK';
        throw PlatformException(code: 'AUTH_DENIED', message: 'denied');
      });

      final nexiPayment = NexiPayment(secretKey: 'secret');

      expect(
        () => nexiPayment.xPayFrontOfficePaga(
            'ALIAS', 'codTrans1', CurrencyUtilsQP.EUR, 2500),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'AUTH_DENIED')),
      );
    });
  });

  group('NexiNpgPayment (NPG Hosted Payment Page)', () {
    const channel = MethodChannel('nexi_payment_npg');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    NexiNpgPayment client() =>
        NexiNpgPayment(hostname: 'sandbox.example', apiKey: 'key');

    NpgHostedPaymentRequest request() => const NpgHostedPaymentRequest(
          orderId: 'order-1',
          amount: 100,
          description: 'test order',
        );

    test('encodes credentials and request fields', () async {
      late MethodCall received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        received = call;
        return <String, dynamic>{'status': 'success'};
      });

      await client().payWithHostedPaymentPage(request());

      expect(received.method, 'npgHostedPaymentPage');
      final args = Map<String, dynamic>.from(received.arguments as Map);
      expect(args['hostname'], 'sandbox.example');
      expect(args['apiKey'], 'key');
      expect(args['orderId'], 'order-1');
      expect(args['amount'], 100);
      expect(args['currency'], 'EUR');
      expect(args['language'], 'ita');
      expect(args['description'], 'test order');
      expect(args['notificationUrl'], isNull);
    });

    test('decodes a success payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return <String, dynamic>{
          'status': 'success',
          'orderId': 'order-1',
          'operationId': 'op-1',
          'operationResult': 'EXECUTED',
          'operationAmount': '100',
          'operationCurrency': 'EUR',
          'paymentCircuit': 'VISA',
        };
      });

      final result = await client().payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.success);
      expect(result.isSuccess, isTrue);
      expect(result.orderId, 'order-1');
      expect(result.operationId, 'op-1');
      expect(result.operationResult, 'EXECUTED');
      expect(result.operationAmount, '100');
      expect(result.operationCurrency, 'EUR');
      expect(result.paymentCircuit, 'VISA');
    });

    test('decodes a canceled payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return <String, dynamic>{'status': 'canceled'};
      });

      final result = await client().payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.canceled);
      expect(result.isCanceled, isTrue);
    });

    test('decodes an error payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return <String, dynamic>{
          'status': 'error',
          'errorCode': 'ServerErrorException',
          'errorMessage': 'boom',
        };
      });

      final result = await client().payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.error);
      expect(result.errorCode, 'ServerErrorException');
      expect(result.errorMessage, 'boom');
    });

    test('maps PlatformException to an error result', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'IN_PROGRESS', message: 'busy');
      });

      final result = await client().payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.error);
      expect(result.errorCode, 'IN_PROGRESS');
      expect(result.errorMessage, 'busy');
    });

    test('a null channel reply (res ?? const {}) decodes to an error result',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      final result = await client().payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.error);
      expect(result.isSuccess, isFalse);
    });

    test(
        'maps a MissingPluginException (e.g. web/desktop) to an error result instead of throwing',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('No implementation found');
      });

      final result = await client().payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.error);
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'NPG is not supported on this platform.');
    });
  });

  group('NpgPaymentResult.fromMap', () {
    test('an empty map decodes to an error status', () {
      final result = NpgPaymentResult.fromMap(const <String, dynamic>{});

      expect(result.status, NpgPaymentStatus.error);
      expect(result.isSuccess, isFalse);
      expect(result.isCanceled, isFalse);
      expect(result.orderId, isNull);
      expect(result.errorCode, isNull);
      expect(result.errorMessage, isNull);
    });

    test('null-ish/unrecognized status values decode to an error status', () {
      final result = NpgPaymentResult.fromMap(<String, dynamic>{
        'status': null,
        'orderId': null,
      });

      expect(result.status, NpgPaymentStatus.error);

      final unknownStatus = NpgPaymentResult.fromMap(<String, dynamic>{
        'status': 'something-unexpected',
      });

      expect(unknownStatus.status, NpgPaymentStatus.error);
    });
  });

  group('NPG hostname validation', () {
    const channel = MethodChannel('nexi_payment_npg');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    /// Returns the result plus whether the platform was reached at all.
    Future<({NpgPaymentResult result, bool calledNative})> payWith(
        String hostname) async {
      var calledNative = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calledNative = true;
        return <String, dynamic>{'status': 'success'};
      });
      final result =
          await NexiNpgPayment(hostname: hostname, apiKey: 'key')
              .payWithHostedPaymentPage(
        const NpgHostedPaymentRequest(orderId: 'order-1', amount: 100),
      );
      return (result: result, calledNative: calledNative);
    }

    test('a hostname that is not a bare host is rejected offline', () async {
      // The Android SDK rejects these itself, the iOS one accepts them and
      // fails later with NPG_ERROR. The plugin makes both fast and identical.
      for (final bad in <String>[
        'https://stg-ta.nexigroup.com',
        'http://stg-ta.nexigroup.com',
        'stg-ta.nexigroup.com/api',
        '',
        '   ',
      ]) {
        final outcome = await payWith(bad);

        expect(outcome.result.status, NpgPaymentStatus.error, reason: bad);
        expect(outcome.result.errorCode, 'INVALID_CREDENTIALS', reason: bad);
        expect(outcome.calledNative, isFalse,
            reason: 'must not reach the platform for: $bad');
      }
    });

    test('the message suggests the host that should have been used', () async {
      final outcome = await payWith('https://stg-ta.nexigroup.com/api');

      // The suggestion strips both the scheme and the path; the message also
      // echoes what was passed, which is why it still mentions the URL.
      expect(outcome.result.errorMessage, contains('use "stg-ta.nexigroup.com"'));
      expect(outcome.result.errorMessage,
          contains('rather than "https://stg-ta.nexigroup.com/api"'));
    });

    test('a bare host reaches the platform', () async {
      final outcome = await payWith('stg-ta.nexigroup.com');

      expect(outcome.calledNative, isTrue);
      expect(outcome.result.status, NpgPaymentStatus.success);
    });
  });

  group('NPG outcome classification', () {
    const channel = MethodChannel('nexi_payment_npg');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    /// Both native SDKs report "the flow finished" as status success, even
    /// when the operation itself failed, so the platform's verdict alone
    /// cannot be trusted.
    Future<NpgPaymentResult> payReporting(String? operationResult) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return <String, dynamic>{
          'status': 'success',
          'orderId': 'order-1',
          'operationId': 'op-1',
          if (operationResult != null) 'operationResult': operationResult,
        };
      });
      return NexiNpgPayment(hostname: 'h', apiKey: 'k')
          .payWithHostedPaymentPage(
        const NpgHostedPaymentRequest(orderId: 'order-1', amount: 100),
      );
    }

    test('a failed 3DS is an error, not a success', () async {
      // Regression: pressing "AUTENTICAZIONE FALLITA" on the 3DS page made
      // the SDK report completion, and the plugin called it a successful
      // payment while carrying THREEDS_FAILED in operationResult.
      final result = await payReporting('THREEDS_FAILED');

      expect(result.status, NpgPaymentStatus.error);
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'THREEDS_FAILED');
      expect(result.operationResult, 'THREEDS_FAILED');
      expect(result.errorMessage, contains('did not succeed'));
    });

    test('every final negative outcome is an error', () async {
      for (final outcome in <String>[
        'DECLINED',
        'DENIED_BY_RISK',
        'THREEDS_FAILED',
        'FAILED',
        'CANCELED',
        'VOIDED',
        'REFUNDED',
      ]) {
        final result = await payReporting(outcome);

        expect(result.status, NpgPaymentStatus.error, reason: outcome);
        expect(result.errorCode, outcome, reason: outcome);
      }
    });

    test('a non-final outcome is not reported as a success either', () async {
      for (final outcome in <String>['PENDING', 'THREEDS_VALIDATED']) {
        final result = await payReporting(outcome);

        expect(result.status, NpgPaymentStatus.error, reason: outcome);
        expect(result.errorCode, outcome, reason: outcome);
        expect(result.errorMessage, contains('Verify the order server-side'),
            reason: outcome);
      }
    });

    test('genuine successes are untouched', () async {
      for (final outcome in <String>['AUTHORIZED', 'EXECUTED']) {
        final result = await payReporting(outcome);

        expect(result.status, NpgPaymentStatus.success, reason: outcome);
        expect(result.isSuccess, isTrue, reason: outcome);
        expect(result.errorCode, isNull, reason: outcome);
      }
    });

    test('without an operationResult the platform verdict stands', () async {
      final result = await payReporting(null);

      expect(result.status, NpgPaymentStatus.success);
      expect(result.operationResult, isNull);
    });
  });

  group('NPG outcome recovery (NPGSDK 1.1.0 parsing defect)', () {
    const channel = MethodChannel('nexi_payment_npg');

    /// The orders API payload of a real sandbox payment, trimmed but
    /// faithful — including the object-valued `additionalData` that the
    /// native SDK models as a string, which is the whole reason recovery
    /// exists.
    String orderPayload({
      String operationResult = 'EXECUTED',
      String operationType = 'AUTHORIZATION',
    }) =>
        '''
{"operations":[{"additionalData":{"maskedPan":"450903******5006",
"authorizationCode":"403679","status":"CAPTURED"},"channel":"ECOMMERCE",
"operationAmount":"100","operationCurrency":"EUR",
"operationId":"599723930724962039","operationResult":"$operationResult",
"operationTime":"2026-07-22 14:57:44.411","operationType":"$operationType",
"orderId":"order-1","paymentCircuit":"VISA","paymentMethod":"CARD"}],
"orderStatus":{"authorizedAmount":"100","capturedAmount":"100"}}''';

    /// Makes the platform channel report the Android-shaped parsing failure
    /// (a result map), or the iOS-shaped one (a PlatformException).
    void stubParsingFailure({bool asException = false}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (asException) {
          throw PlatformException(
            code: NpgPaymentResult.resultParsingFailedCode,
            message: 'could not parse',
          );
        }
        return <String, dynamic>{
          'status': 'error',
          'errorCode': NpgPaymentResult.resultParsingFailedCode,
          'errorMessage': 'could not parse',
        };
      });
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    NexiNpgPayment client({
      required NpgHttpGet httpGet,
      bool recover = true,
    }) =>
        NexiNpgPayment(
          hostname: 'stg-ta.nexigroup.com',
          apiKey: '5d952446-9004-4023-9eae-a527a152846b',
          recoverOutcomeOnParsingFailure: recover,
          httpGet: httpGet,
        );

    NpgHostedPaymentRequest request() =>
        const NpgHostedPaymentRequest(orderId: 'order-1', amount: 100);

    test('a payment the SDK could not parse is recovered as a success',
        () async {
      stubParsingFailure();

      final result = await client(
        httpGet: (url, headers) async => NpgHttpResponse(200, orderPayload()),
      ).payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.success);
      expect(result.isSuccess, isTrue);
      expect(result.operationResult, 'EXECUTED');
      expect(result.orderId, 'order-1');
      expect(result.operationId, '599723930724962039');
      expect(result.operationAmount, '100');
      expect(result.operationCurrency, 'EUR');
      expect(result.paymentCircuit, 'VISA');
      expect(result.errorCode, isNull);
    });

    test('recovery also runs when iOS reports the failure as an exception',
        () async {
      stubParsingFailure(asException: true);

      final result = await client(
        httpGet: (url, headers) async => NpgHttpResponse(200, orderPayload()),
      ).payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.success);
      expect(result.operationResult, 'EXECUTED');
    });

    test('the orders API is called with the documented URL and headers',
        () async {
      stubParsingFailure();
      late Uri calledUrl;
      late Map<String, String> sentHeaders;

      await client(httpGet: (url, headers) async {
        calledUrl = url;
        sentHeaders = headers;
        return NpgHttpResponse(200, orderPayload());
      }).payWithHostedPaymentPage(request());

      expect(calledUrl.scheme, 'https');
      expect(calledUrl.host, 'stg-ta.nexigroup.com');
      expect(calledUrl.path, '/api/phoenix-0.0/psp/api/v1/orders/order-1');
      expect(sentHeaders['X-Api-Key'], '5d952446-9004-4023-9eae-a527a152846b');
      expect(sentHeaders['Content-Type'], 'application/json');
      // The API rejects a Correlation-Id that is not a UUID.
      expect(
        sentHeaders['Correlation-Id'],
        matches(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      );
    });

    test('a genuinely declined payment is reported as a declined error',
        () async {
      stubParsingFailure();

      final result = await client(
        httpGet: (url, headers) async =>
            NpgHttpResponse(200, orderPayload(operationResult: 'DECLINED')),
      ).payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.error);
      expect(result.errorCode, 'DECLINED');
      expect(result.operationResult, 'DECLINED');
      expect(result.errorMessage, contains('did not succeed'));
    });

    test('a non-final outcome keeps the original "outcome unknown" result',
        () async {
      stubParsingFailure();

      for (final pending in <String>['PENDING', 'THREEDS_VALIDATED']) {
        final result = await client(
          httpGet: (url, headers) async =>
              NpgHttpResponse(200, orderPayload(operationResult: pending)),
        ).payWithHostedPaymentPage(request());

        expect(result.status, NpgPaymentStatus.error, reason: pending);
        expect(result.errorCode, NpgPaymentResult.resultParsingFailedCode,
            reason: pending);
      }
    });

    test('an unhappy orders API leaves the original result untouched',
        () async {
      stubParsingFailure();

      final failures = <String, NpgHttpGet>{
        '404': (url, headers) async => const NpgHttpResponse(404, ''),
        '401': (url, headers) async =>
            const NpgHttpResponse(401, '{"errcode":"401"}'),
        'garbage body': (url, headers) async =>
            const NpgHttpResponse(200, 'not json'),
        'no operations': (url, headers) async =>
            const NpgHttpResponse(200, '{"operations":[]}'),
        'transport error': (url, headers) async =>
            throw const SocketException('no network'),
      };

      for (final entry in failures.entries) {
        final result =
            await client(httpGet: entry.value).payWithHostedPaymentPage(
          request(),
        );

        expect(result.status, NpgPaymentStatus.error, reason: entry.key);
        expect(result.errorCode, NpgPaymentResult.resultParsingFailedCode,
            reason: entry.key);
      }
    });

    test(
        'a retried payment resolves to its newest attempt, whatever the '
        'order the API lists operations in', () async {
      // A declined first try and an authorized retry inside the same session.
      // Trusting list order would report DECLINED for a payment that
      // succeeded, which is exactly what recovery must never do.
      const declined = '''
{"operationId":"op-declined","operationResult":"DECLINED",
"operationType":"AUTHORIZATION","orderId":"order-1",
"operationTime":"2026-07-25 16:29:40.000"}''';
      const authorized = '''
{"operationId":"op-authorized","operationResult":"EXECUTED",
"operationType":"AUTHORIZATION","orderId":"order-1","operationAmount":"100",
"operationCurrency":"EUR","operationTime":"2026-07-25 16:29:56.783"}''';

      for (final ordering in <String, String>{
        'oldest first': '{"operations":[$declined,$authorized]}',
        'newest first': '{"operations":[$authorized,$declined]}',
      }.entries) {
        stubParsingFailure();

        final result = await client(
          httpGet: (url, headers) async => NpgHttpResponse(200, ordering.value),
        ).payWithHostedPaymentPage(request());

        expect(result.status, NpgPaymentStatus.success, reason: ordering.key);
        expect(result.operationId, 'op-authorized', reason: ordering.key);
        expect(result.operationResult, 'EXECUTED', reason: ordering.key);
      }
    });

    test('without usable timestamps the API list order is used', () async {
      stubParsingFailure();
      const payload = '''
{"operations":[
{"operationId":"op-old","operationResult":"DECLINED","operationType":"AUTHORIZATION",
"orderId":"order-1"},
{"operationId":"op-new","operationResult":"EXECUTED","operationType":"AUTHORIZATION",
"orderId":"order-1","operationTime":"not a date"}]}''';

      final result = await client(
        httpGet: (url, headers) async => const NpgHttpResponse(200, payload),
      ).payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.success);
      expect(result.operationId, 'op-new');
    });

    test('the authorization operation wins over other operations', () async {
      stubParsingFailure();
      const payload = '''
{"operations":[
{"operationId":"op-refund","operationResult":"REFUNDED","operationType":"REFUND",
"orderId":"order-1"},
{"operationId":"op-auth","operationResult":"AUTHORIZED","operationType":"AUTHORIZATION",
"orderId":"order-1","operationAmount":"100","operationCurrency":"EUR"}]}''';

      final result = await client(
        httpGet: (url, headers) async => const NpgHttpResponse(200, payload),
      ).payWithHostedPaymentPage(request());

      expect(result.status, NpgPaymentStatus.success);
      expect(result.operationId, 'op-auth');
      expect(result.operationResult, 'AUTHORIZED');
    });

    test('recovery can be turned off, and never runs for other errors',
        () async {
      stubParsingFailure();
      var called = false;
      Future<NpgHttpResponse> spy(Uri url, Map<String, String> headers) async {
        called = true;
        return NpgHttpResponse(200, orderPayload());
      }

      final optedOut = await client(httpGet: spy, recover: false)
          .payWithHostedPaymentPage(request());

      expect(called, isFalse);
      expect(optedOut.errorCode, NpgPaymentResult.resultParsingFailedCode);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAUTHORIZED', message: 'nope');
      });

      final otherError =
          await client(httpGet: spy).payWithHostedPaymentPage(request());

      expect(called, isFalse);
      expect(otherError.errorCode, 'UNAUTHORIZED');
    });
  });
}
