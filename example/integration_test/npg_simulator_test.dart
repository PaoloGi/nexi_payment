import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';
import 'package:nexi_payment_example/main.dart';

import 'helpers.dart';

/// Plain `integration_test` tests for targets Patrol cannot drive — today the
/// iOS simulator, which has no RunnerUITests target (see TESTING.md). Run
/// with:
///
/// ```bash
/// cd example
/// flutter test integration_test/npg_simulator_test.dart -d <simulator id>
/// ```
///
/// **This file must stay in `integration_test/`.** Run from anywhere else and
/// the tooling warns "integration_test plugin was not detected" and executes
/// the tests on the host VM instead of the device, where the plugin does not
/// exist: the channel then throws `MissingPluginException` and every result
/// comes back `NOT_IMPLEMENTED` rather than exercising the native SDK.
///
/// Only flows that never need native automation belong here: the credential
/// validations are rejected by the native SDK before any checkout UI or
/// network call, so they complete on their own. Anything that opens the
/// Hosted Payment Page needs a native dismissal and stays in the Patrol
/// suite.
///
/// The two credential tests below deliberately mirror `npg_gateway_test.dart`.
/// That is not redundancy to tidy away: those run under Patrol, which cannot
/// target iOS here, so this file is the only place they are exercised against
/// the iOS SDK. Keep the pair in sync.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the example app shows both gateway buttons', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('PAY'), findsOneWidget);
    expect(find.text('PAY WITH NPG (HPP)'), findsOneWidget);
  });

  testWidgets('NPG rejects a hostname that includes a scheme', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final npg = NexiNpgPayment(
      hostname: 'https://$npgSandboxHostname',
      apiKey: npgSandboxApiKey,
    );

    final result = await npg.payWithHostedPaymentPage(newRequest());

    expect(result.status, NpgPaymentStatus.error);
    expect(result.isSuccess, isFalse);
    expect(result.errorCode, 'INVALID_CREDENTIALS');
  });

  testWidgets('NPG rejects an API key that is not a UUID', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final npg = NexiNpgPayment(
      hostname: npgSandboxHostname,
      apiKey: 'clearly-not-a-uuid',
    );

    final result = await npg.payWithHostedPaymentPage(newRequest());

    expect(result.status, NpgPaymentStatus.error);
    expect(result.errorCode, 'INVALID_CREDENTIALS');
  });
}
