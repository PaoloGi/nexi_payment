// PlatformAutomator has no pressBack(): it is Android-only and stayed on the
// older NativeAutomator API, which is still the way to dismiss a native
// checkout Activity.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexi_payment/models/currency_utils_qp.dart';
import 'package:nexi_payment/models/environment_utils.dart';
import 'package:nexi_payment/nexi_payment.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// Integration tests for the classic XPay gateway.
///
/// These drive the plugin API directly rather than tapping the example app's
/// button: tapping would make patrol wait for a frame that never arrives once
/// the SDK's checkout Activity is in front.
void main() {
  patrolTest('the classic checkout opens without crashing', ($) async {
    await $.pumpWidgetAndSettle(const TestHarness());

    final nexiPayment = NexiPayment(
      secretKey: classicSecretKey,
      environment: EnvironmentUtils.TEST,
      domain: 'https://ecommerce.nexi.it',
    );

    // Deliberately not awaited: the checkout WebView stays open until the
    // user acts on it.
    final pending = nexiPayment.xPayFrontOfficePaga(
      classicAlias,
      'it${DateTime.now().millisecondsSinceEpoch}',
      CurrencyUtilsQP.EUR,
      2500,
    );

    String? outcome;
    Object? failure;
    unawaited(pending.then(
      (value) => outcome = value,
      onError: (Object error) => failure = error,
    ));

    // Real time, not $.pump: no frames are produced while the checkout
    // Activity is in front. Keep this short — the instrumentation tears the
    // app down if a non-instrumented Activity holds the foreground too long
    // ("Killing ... due to finished inst"), which shows up as a test that
    // never reports rather than one that fails.
    await Future<void>.delayed(const Duration(seconds: 6));

    // If the SDK cannot start its checkout Activity the app process dies and
    // this test fails outright — that is how the androidx.webkit
    // "Unknown feature PAYMENT_REQUEST" regression surfaced.
    expect(failure, isNull, reason: 'the checkout should open, not fail');
    expect(outcome, isNull, reason: 'the checkout stays open until the user acts');

    // Best effort cleanup so the next test starts from a clean screen. This
    // does not resolve `pending`; see the skipped test below.
    await $.native.pressBack();
  });

  patrolTest(
    'dismissing the classic checkout with the back button reports an outcome',
    ($) async {
      await $.pumpWidgetAndSettle(const TestHarness());

      final nexiPayment = NexiPayment(
        secretKey: classicSecretKey,
        environment: EnvironmentUtils.TEST,
        domain: 'https://ecommerce.nexi.it',
      );

      final pending = nexiPayment.xPayFrontOfficePaga(
        classicAlias,
        'it${DateTime.now().millisecondsSinceEpoch}',
        CurrencyUtilsQP.EUR,
        2500,
      );
      await Future<void>.delayed(const Duration(seconds: 15));
      await $.native.pressBack();

      String outcome;
      try {
        outcome = await pending.timeout(const Duration(seconds: 30));
      } on Object catch (e) {
        outcome = '$e';
      }

      expect(outcome, isNotEmpty);
    },
    // KNOWN LIMITATION, not a flake. BaseWebViewActivity.onBackPressed in
    // XPaySDK only calls WebView.goBack() or Activity.onBackPressed(): it
    // never invokes the FrontOfficeCallbackQP, so finishing the checkout with
    // the system back button leaves the Dart future pending forever.
    // Cancelling through the payment page's own cancel link works, because
    // the SDK detects its urlBack navigation. See TESTING.md.
    skip: true,
  );
}
