// PlatformAutomator has no pressBack(): it is Android-only and stayed on the
// older NativeAutomator API, which is still the way to dismiss a native
// checkout Activity.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

    // No `domain` override: TEST must resolve to int-ecommerce.nexi.it.
    // Passing the production URL here used to send the test terminal's
    // request to production, which rejects it before the card form loads.
    final nexiPayment = NexiPayment(
      secretKey: classicSecretKey,
      environment: EnvironmentUtils.TEST,
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
    unawaited(
      pending.then(
        (value) => outcome = value,
        onError: (Object error) => failure = error,
      ),
    );

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
    expect(
      outcome,
      isNull,
      reason: 'the checkout stays open until the user acts',
    );

    // Best effort cleanup so the next test starts from a clean screen. This
    // does not resolve `pending`; see the skipped test below.
    await $.native.pressBack();
  });

  // The regression this guards: XPaySDK's BaseWebViewActivity.onBackPressed
  // only calls WebView.goBack() or Activity.onBackPressed(), so it never
  // invokes FrontOfficeCallbackQP. Until the plugin started watching the
  // checkout's lifecycle, dismissing it this way left the Dart future pending
  // forever and refused every later payment with IN_PROGRESS.
  patrolTest(
    'dismissing the classic checkout with the back button reports a cancel',
    ($) async {
      await $.pumpWidgetAndSettle(const TestHarness());

      final nexiPayment = NexiPayment(
        secretKey: classicSecretKey,
        environment: EnvironmentUtils.TEST,
      );

      final pending = nexiPayment.xPayFrontOfficePaga(
        classicAlias,
        'it${DateTime.now().millisecondsSinceEpoch}',
        CurrencyUtilsQP.EUR,
        2500,
      );
      await Future<void>.delayed(const Duration(seconds: 15));
      await $.native.pressBack();

      // Same outcome the payment page's own cancel link produces.
      expect(
        await pending.timeout(const Duration(seconds: 30)),
        NexiPayment.canceledByUser,
      );

      // ...and the plugin must be usable again, not stuck in progress. This
      // one is dismissed the same way: a payment only completes once its
      // checkout is gone, so it cannot be awaited before pressing back.
      final afterwards = nexiPayment.xPayFrontOfficePaga(
        classicAlias,
        'it${DateTime.now().millisecondsSinceEpoch}',
        CurrencyUtilsQP.EUR,
        2500,
      );
      await Future<void>.delayed(const Duration(seconds: 15));
      await $.native.pressBack();
      expect(
        await afterwards.timeout(const Duration(seconds: 30)),
        NexiPayment.canceledByUser,
      );
    },
  );
}
