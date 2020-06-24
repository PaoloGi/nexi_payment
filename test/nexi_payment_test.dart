import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexi_payment/nexi_payment.dart';

void main() {
  const MethodChannel channel = MethodChannel('nexi_payment');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

//  test('getPlatformVersion', () async {
//    expect(await NexiPayment.platformVersion, '42');
//  });
}
