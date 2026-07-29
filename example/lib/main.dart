import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:nexi_payment/nexi_payment.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';
import 'package:nexi_payment_example/payment_result_dialog.dart';
import 'package:nexi_payment_example/second_page.dart';

/// Nexi's public sandbox credentials, passed at run time so they never end up
/// in git:
/// flutter run --dart-define=NPG_HOSTNAME=... --dart-define=NPG_API_KEY=...
///
/// **Do not copy this pattern for a real terminal.** `--dart-define` values are
/// compiled into the binary and can be read straight out of a shipped app, so
/// they keep credentials out of your repository but not out of your APK/IPA.
/// A production `apiKey` authorises refunds and captures, not just payments:
/// fetch it at run time from your own backend, behind your own authentication,
/// and keep it in memory. See "Where the API key should live" in
/// INTEGRATION.md.
const String npgHostname = String.fromEnvironment('NPG_HOSTNAME');
const String npgApiKey = String.fromEnvironment('NPG_API_KEY');

/// Classic XPay credentials, likewise supplied at run time:
/// flutter run --dart-define=XPAY_ALIAS=... --dart-define=XPAY_SECRET_KEY=...
///
/// The same warning applies, and more sharply: `secretKey` is the MAC signing
/// key for your terminal. Everything above about not shipping it in the binary
/// holds here too.
const String xpayAlias =
    String.fromEnvironment('XPAY_ALIAS', defaultValue: '_your_alias_');
const String xpaySecretKey =
    String.fromEnvironment('XPAY_SECRET_KEY', defaultValue: '_your_secret_key_');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: TestPage());
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<StatefulWidget> createState() => TestPageState();
}

class TestPageState extends State<TestPage> {
  late NexiPayment _nexiPayment;

  /// Identifier the card was last stored against, remembered so the recurring
  /// charge below can use it.
  ///
  /// A fresh one is generated per attempt because **XPay refuses a
  /// `num_contratto` that already exists**: it dead-ends the checkout on a
  /// "operazione non andata a buon fine" page that the back button cannot
  /// leave, so the payment never completes. In a real app this is yours to
  /// choose and to persist — one per customer, or per saved card — and it must
  /// be new every time you store a card.
  String? _storedContractId;

  @override
  void initState() {
    super.initState();

    // Leave `domain` unset: the environment picks the right host
    // (TEST -> int-ecommerce.nexi.it, PROD -> ecommerce.nexi.it). Setting a
    // domain overrides the environment's host, so passing the production URL
    // here with environment TEST sends test-terminal requests to production,
    // which Nexi rejects with a generic error page.
    //
    _nexiPayment = NexiPayment(
      secretKey: xpaySecretKey,
      environment: EnvironmentUtils.TEST,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      // SafeArea + a scroll view keep the buttons reachable and prevent a
      // RenderFlex overflow on short screens (small phones, split-screen),
      // while Center keeps them centered when there is room to spare.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  // codTrans must be unique per attempt: Nexi rejects a
                  // reused one with a generic "operation failed" page.
                  onPressed: () =>
                      _paga("and${DateTime.now().millisecondsSinceEpoch}"),
                  child: const Text("PAY"),
                ),
                ElevatedButton(
                  // Same payment, but asking XPay to keep the card against a
                  // contract so it can be charged again later. The contract id
                  // must not already exist, hence a fresh one each time.
                  onPressed: () => _paga(
                    "and${DateTime.now().millisecondsSinceEpoch}",
                    storeCardAs:
                        "nexi-example-${DateTime.now().millisecondsSinceEpoch}",
                  ),
                  child: const Text("PAY & STORE CARD"),
                ),
                ElevatedButton(
                  // Charges the card stored above: no checkout, no customer.
                  onPressed: _pagaRicorrente,
                  child: const Text("CHARGE STORED CARD"),
                ),
                ElevatedButton(
                  onPressed: _pagaNpg,
                  child: const Text("PAY WITH NPG (HPP)"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push<Widget>(
                    context,
                    MaterialPageRoute(builder: (context) => const SecondPage()),
                  ),
                  child: const Text("GO to A SECOND PAGE"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _paga(String codTrans, {String? storeCardAs}) async {
    try {
      var res = await _nexiPayment.xPayFrontOfficePaga(
        xpayAlias,
        codTrans,
        CurrencyUtilsQP.EUR,
        2500,
        extraParameters: storeCardAs == null
            ? const <String, String>{}
            : <String, String>{
                'num_contratto': storeCardAs,
                'tipo_servizio': 'paga_multi',
              },
      );
      // The card is only stored if the payment itself went through.
      if (storeCardAs != null && res == 'OK') {
        _storedContractId = storeCardAs;
      }
      if (!mounted) return;
      if (res == NexiPayment.canceledByUser) {
        showPaymentResultDialog(
          context,
          PaymentResultKind.canceled,
          detail: 'You canceled the checkout.',
        );
      } else {
        showPaymentResultDialog(
          context,
          PaymentResultKind.success,
          detail: 'Order $codTrans was authorized.',
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      showPaymentResultDialog(
        context,
        PaymentResultKind.error,
        detail: '${e.code}${e.message == null ? '' : ' — ${e.message}'}',
      );
    }
  }

  /// Charges the card stored by "PAY & STORE CARD" — no checkout is shown.
  void _pagaRicorrente() async {
    final contractId = _storedContractId;
    if (contractId == null) {
      showPaymentResultDialog(
        context,
        PaymentResultKind.error,
        detail: 'No stored card yet — run "PAY & STORE CARD" first.',
      );
      return;
    }
    final codTrans = "rec${DateTime.now().millisecondsSinceEpoch}";
    try {
      final result = await _nexiPayment.xPayRecurringPayment(
        alias: xpayAlias,
        contractId: contractId,
        codTrans: codTrans,
        amount: 999,
      );
      if (!mounted) return;
      showPaymentResultDialog(
        context,
        result.isSuccess ? PaymentResultKind.success : PaymentResultKind.error,
        detail: result.isSuccess
            ? 'Charged 9,99 € on the stored card — auth ${result.authCode}'
            : '${result.errorCode ?? 'error'} — ${result.errorMessage ?? ''}',
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      showPaymentResultDialog(
        context,
        PaymentResultKind.error,
        detail: '${e.code}${e.message == null ? '' : ' — ${e.message}'}',
      );
    }
  }

  void _pagaNpg() async {
    if (npgHostname.isEmpty || npgApiKey.isEmpty) {
      showPaymentResultDialog(
        context,
        PaymentResultKind.error,
        detail:
            'Missing NPG credentials: run with '
            '--dart-define=NPG_HOSTNAME=... --dart-define=NPG_API_KEY=...',
      );
      return;
    }
    final orderId = "ex${DateTime.now().millisecondsSinceEpoch}";
    final npg = NexiNpgPayment(hostname: npgHostname, apiKey: npgApiKey);
    final result = await npg.payWithHostedPaymentPage(
      NpgHostedPaymentRequest(
        orderId: orderId,
        amount: 100,
        currency: "EUR",
        language: "ita",
        description: "nexi_payment example NPG payment",
      ),
    );
    if (!mounted) return;
    switch (result.status) {
      case NpgPaymentStatus.success:
        showPaymentResultDialog(
          context,
          PaymentResultKind.success,
          detail: 'Order $orderId — ${result.operationResult ?? 'paid'}',
        );
      case NpgPaymentStatus.canceled:
        showPaymentResultDialog(
          context,
          PaymentResultKind.canceled,
          detail: 'You canceled the checkout.',
        );
      case NpgPaymentStatus.error:
        showPaymentResultDialog(
          context,
          PaymentResultKind.error,
          detail:
              '${result.errorCode ?? 'error'}${result.errorMessage == null ? '' : ' — ${result.errorMessage}'}',
        );
    }
  }
}
