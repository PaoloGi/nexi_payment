// PlatformAutomator has no pressBack(): it is Android-only and stayed on the
// older NativeAutomator API, which is still the way to dismiss a native
// checkout Activity.
// ignore_for_file: deprecated_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// Integration tests for the NPG gateway that drive the plugin API directly.
///
/// The credential-validation tests are fully offline: the native SDK rejects
/// malformed input before any network call, so they are deterministic and safe
/// to run anywhere. The Hosted Payment Page tests need sandbox credentials
/// (see TESTING.md).
void main() {
  patrolTest('NPG rejects a hostname that includes a scheme', ($) async {
    await $.pumpWidgetAndSettle(const TestHarness());

    // The native SDK validates the hostname against a bare-host regex, so a
    // URL with "https://" is rejected before any request is made.
    final npg = NexiNpgPayment(
      hostname: 'https://$npgSandboxHostname',
      apiKey: npgSandboxApiKey,
    );

    final result = await npg.payWithHostedPaymentPage(newRequest());

    expect(result.status, NpgPaymentStatus.error);
    expect(result.isSuccess, isFalse);
    expect(result.errorCode, 'INVALID_CREDENTIALS');
  });

  patrolTest('NPG rejects an API key that is not a UUID', ($) async {
    await $.pumpWidgetAndSettle(const TestHarness());

    final npg = NexiNpgPayment(
      hostname: npgSandboxHostname,
      apiKey: 'clearly-not-a-uuid',
    );

    final result = await npg.payWithHostedPaymentPage(newRequest());

    expect(result.status, NpgPaymentStatus.error);
    expect(result.errorCode, 'INVALID_CREDENTIALS');
  });

  patrolTest(
    'NPG opens the Hosted Payment Page and always completes when dismissed',
    ($) async {
      await $.pumpWidgetAndSettle(const TestHarness());

      final npg = NexiNpgPayment(
        hostname: npgSandboxHostname,
        apiKey: npgSandboxApiKey,
      );

      // Deliberately not awaited: the checkout WebView is showing while we
      // dismiss it natively.
      final pending = npg.payWithHostedPaymentPage(newRequest());
      await $.pump(const Duration(seconds: 8));
      await $.native.pressBack();

      // The regression this guards: dismissing the checkout used to leave the
      // future pending forever — on iOS it also left the plugin refusing every
      // later payment with IN_PROGRESS for the life of the app.
      final result = await pending.timeout(const Duration(seconds: 30));

      // Both platforms now report a dismissed checkout the same way: Android
      // gets RESULT_CANCELED with no data, and iOS reports a checkout that
      // disappeared without the SDK saying anything.
      expect(result.status, NpgPaymentStatus.canceled);
      expect(result.isSuccess, isFalse);

      // ...and the plugin must be usable again, not stuck in progress.
      final afterwards = await npg
          .payWithHostedPaymentPage(newRequest())
          .timeout(const Duration(seconds: 30));
      expect(afterwards.errorCode, isNot('IN_PROGRESS'));
      await $.native.pressBack();
    },
  );

  patrolTest('NPG refuses a second concurrent payment', ($) async {
    await $.pumpWidgetAndSettle(const TestHarness());

    final npg = NexiNpgPayment(
      hostname: npgSandboxHostname,
      apiKey: npgSandboxApiKey,
    );

    final first = npg.payWithHostedPaymentPage(newRequest());
    await $.pump(const Duration(seconds: 5));

    final second = await npg.payWithHostedPaymentPage(newRequest());
    expect(second.status, NpgPaymentStatus.error);
    expect(second.errorCode, 'IN_PROGRESS');

    // Clean up the still-open checkout so the next test starts fresh.
    await $.native.pressBack();
    await first.timeout(const Duration(seconds: 30));
  });
}
