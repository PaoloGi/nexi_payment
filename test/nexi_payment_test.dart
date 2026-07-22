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
        NexiNpgPayment(hostname: 'https://sandbox.example', apiKey: 'key');

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
      expect(args['hostname'], 'https://sandbox.example');
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
}
