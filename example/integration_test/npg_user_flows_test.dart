// NativeAutomator (`$.native`) is the legacy API, but it is the one that can
// type into and tap the native checkout, exactly like the other files here.
// ignore_for_file: deprecated_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// Full user-behaviour flows: these type Nexi's published test cards into the
/// real sandbox Hosted Payment Page and assert on the result the app gets —
/// paying, failing 3DS, and having the card declined.
///
/// **Off by default.** They drive Nexi's hosted page, which is third-party
/// HTML that can change under us, and each run costs a real sandbox payment,
/// so a routine `patrol test` must not depend on them. Flip
/// [_skipHostedPageFlows] to run them, and expect to re-check the selectors
/// below if Nexi has redesigned the page since.
///
/// They also cannot run on iOS today: Patrol needs a `RunnerUITests` target
/// that the example app does not have (see TESTING.md). On iOS, drive these
/// flows by hand with `docs/DEVICE_TESTING.md`.
///
/// What they do *not* prove: that the orders-API recovery ran. Recovery only
/// engages when the native SDK fails to parse the outcome, which the NPGSDK
/// 1.1.0 defect causes only intermittently — a success here is normally the
/// plain path. The recovery logic is covered by the unit tests instead.
const bool _skipHostedPageFlows = true;

void main() {
  const successCard = '4509034543615006';
  const declinedCard = '4349940199997007';

  patrolTest(
    'a user paying with the success card gets a success',
    ($) async {
      await $.pumpWidgetAndSettle(const TestHarness());

      final result = await _payLikeAUser(
        $,
        cardNumber: successCard,
        threeDsButton: _threeDsPass,
      );

      expect(result.isSuccess, isTrue, reason: 'got: $result');
      expect(result.operationResult, anyOf('EXECUTED', 'AUTHORIZED'));
      expect(result.errorCode, isNull);
    },
    skip: _skipHostedPageFlows,
  );

  patrolTest(
    'a user failing 3DS gets an error, never a success',
    ($) async {
      await $.pumpWidgetAndSettle(const TestHarness());

      final result = await _payLikeAUser(
        $,
        cardNumber: successCard,
        threeDsButton: _threeDsFail,
      );

      // The 2.1.0 regression this pins down: the SDK reports a finished-but-
      // failed payment through its success callback, and the plugin used to
      // believe it.
      expect(
        result.isSuccess,
        isFalse,
        reason: 'a failed 3DS must never be a success, got: $result',
      );
      expect(result.errorCode, 'THREEDS_FAILED');
    },
    skip: _skipHostedPageFlows,
  );

  patrolTest(
    'a user whose card is declined gets an error',
    ($) async {
      await $.pumpWidgetAndSettle(const TestHarness());

      final result = await _payLikeAUser(
        $,
        cardNumber: declinedCard,
        threeDsButton: _threeDsPass,
      );

      expect(
        result.isSuccess,
        isFalse,
        reason: 'the declined test card must not be a success, got: $result',
      );
      expect(result.errorCode, isNotNull);
    },
    skip: _skipHostedPageFlows,
  );
}

/// The sandbox 3DS ("DemoBank") page offers exactly these two buttons.
const String _threeDsPass = 'AUTENTICAZIONE RIUSCITA';
const String _threeDsFail = 'AUTENTICAZIONE FALLITA';

/// Drives one payment the way a user would and returns what the plugin
/// reports back to the app.
///
/// The page is a sequence, not a single form: choose card → fill the fields →
/// PAGA → confirm the summary with PROSEGUI → resolve the 3DS challenge.
Future<NpgPaymentResult> _payLikeAUser(
  PatrolIntegrationTester $, {
  required String cardNumber,
  required String threeDsButton,
}) async {
  final npg = NexiNpgPayment(
    hostname: npgSandboxHostname,
    apiKey: npgSandboxApiKey,
  );

  // Deliberately not awaited: the checkout stays in front while we drive it.
  final pending = npg.payWithHostedPaymentPage(newRequest());

  // Landing page: choose to pay by card. The first load includes the order
  // being created against the sandbox, so give it time.
  await _tapFirstVisible(
    $,
    step: 'choose card payment',
    timeout: const Duration(seconds: 60),
    candidates: [
      Selector(textContains: 'CARTA DI PAGAMENTO'),
      Selector(textContains: 'carta di pagamento'),
      Selector(textContains: 'Usa carta'),
    ],
  );

  // Card form, in visible order. Every one of these is required: the page
  // keeps PAGA disabled until the whole form validates, so a missing email
  // silently costs you the run.
  await _enterTextByIndexOrDump($, cardNumber, index: 0, field: 'card number');
  await _enterTextByIndexOrDump($, '10/28', index: 1, field: 'expiry');
  await _enterTextByIndexOrDump($, '298', index: 2, field: 'CVV');
  await _enterTextByIndexOrDump($, 'Paolo', index: 3, field: 'first name');
  await _enterTextByIndexOrDump($, 'Test', index: 4, field: 'surname');
  await _enterTextByIndexOrDump($, 'paolo.test@example.org',
      index: 5, field: 'email');

  await _tapFirstVisible(
    $,
    step: 'submit the card form',
    timeout: const Duration(seconds: 20),
    candidates: [
      Selector(textStartsWith: 'PAGA'),
      Selector(textStartsWith: 'Paga'),
    ],
  );

  // Summary page ("Riepilogo pagamento"). Treated as optional so the flow
  // still works if Nexi ever drops the extra confirmation step.
  await _tapFirstVisible(
    $,
    step: 'confirm on the summary page',
    timeout: const Duration(seconds: 30),
    required: false,
    candidates: [
      Selector(textContains: 'PROSEGUI'),
      Selector(textContains: 'Prosegui'),
      Selector(textContains: 'CONTINUA'),
    ],
  );

  // Sandbox 3DS challenge. It may legitimately not appear (a card the issuer
  // declines outright never gets there), but if it does appear the expected
  // button must be there — otherwise the run is driving a page we no longer
  // understand, and failing loudly beats timing out.
  final challenged = await _isVisible(
    $,
    Selector(textContains: 'AUTENTICAZIONE'),
    const Duration(seconds: 45),
  );
  if (challenged) {
    await _tapFirstVisible(
      $,
      step: 'resolve the 3DS challenge with "$threeDsButton"',
      timeout: const Duration(seconds: 20),
      candidates: [Selector(textContains: threeDsButton)],
    );
  }

  return pending.timeout(const Duration(seconds: 120));
}

/// Taps the first of [candidates] that becomes visible.
///
/// Fails with a dump of every visible text when none does, unless [required]
/// is false, in which case the step is simply skipped.
Future<void> _tapFirstVisible(
  PatrolIntegrationTester $, {
  required String step,
  required List<Selector> candidates,
  required Duration timeout,
  bool required = true,
}) async {
  // The full timeout goes to the first candidate: they are alternatives for
  // the same element, so once the page is there the others resolve fast.
  var remaining = timeout;
  for (final candidate in candidates) {
    try {
      await $.native.waitUntilVisible(candidate, timeout: remaining);
      await $.native.tap(candidate);
      return;
    } on Exception {
      remaining = const Duration(seconds: 3);
    }
  }
  if (!required) {
    return;
  }
  fail('Could not $step. Visible texts: ${await _visibleTexts($)}');
}

Future<bool> _isVisible(
  PatrolIntegrationTester $,
  Selector selector,
  Duration timeout,
) async {
  try {
    await $.native.waitUntilVisible(selector, timeout: timeout);
    return true;
  } on Exception {
    return false;
  }
}

Future<void> _enterTextByIndexOrDump(
  PatrolIntegrationTester $,
  String text, {
  required int index,
  required String field,
}) async {
  try {
    await $.native.enterTextByIndex(
      text,
      index: index,
      timeout: const Duration(seconds: 20),
    );
  } on Exception {
    fail(
      'Could not type the $field into text field #$index. '
      'Visible texts: ${await _visibleTexts($)}',
    );
  }
}

/// Every non-empty text currently in the native UI tree, for failure
/// messages: it shows what the sandbox page actually says when a selector
/// stops matching.
Future<String> _visibleTexts(PatrolIntegrationTester $) async {
  try {
    final views = await $.native.getNativeViews(null);
    final texts = <String>[];
    void walk(NativeView view) {
      final text = view.text?.trim() ?? '';
      if (text.isNotEmpty) {
        texts.add(text);
      }
      view.children.forEach(walk);
    }

    views.forEach(walk);
    return texts.join(' | ');
  } on Exception catch (error) {
    return '(could not read the native UI tree: $error)';
  }
}
