import 'package:flutter/material.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';

/// Nexi's published sandbox credentials, overridable with --dart-define when
/// testing against your own NPG terminal. See TESTING.md.
///
/// The hostname must be a bare host: the native SDK validates it against a
/// hostname regex and rejects anything containing a scheme or a path.
const String npgSandboxHostname = String.fromEnvironment(
  'NPG_HOSTNAME',
  defaultValue: 'stg-ta.nexigroup.com',
);

/// Must be a UUID: the native SDK rejects any other shape.
const String npgSandboxApiKey = String.fromEnvironment(
  'NPG_API_KEY',
  defaultValue: '5d952446-9004-4023-9eae-a527a152846b',
);

/// Classic XPay test terminal, the same one the example app uses.
const String classicSecretKey = '8A6PBH0TO7F0B9ON2QQH7808VE3QZZLK';
const String classicAlias = 'ALIAS_WEB_00026202';

/// A fresh request; the orderId must be unique per payment attempt.
NpgHostedPaymentRequest newRequest() => NpgHostedPaymentRequest(
      orderId: 'it${DateTime.now().millisecondsSinceEpoch}',
      amount: 100,
      currency: 'EUR',
      language: 'ita',
      description: 'nexi_payment integration test',
    );

/// Minimal app shell for tests that drive the plugin API directly and only
/// need a running engine with an attached Activity.
class TestHarness extends StatelessWidget {
  const TestHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('integration test'))),
    );
  }
}
