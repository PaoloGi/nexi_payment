import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:nexi_payment/nexi_payment.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';
import 'package:nexi_payment_example/payment_result_dialog.dart';
import 'package:nexi_payment_example/second_page.dart';

/// NPG sandbox credentials, passed at run time so they never end up in git:
/// flutter run --dart-define=NPG_HOSTNAME=... --dart-define=NPG_API_KEY=...
const String npgHostname = String.fromEnvironment('NPG_HOSTNAME');
const String npgApiKey = String.fromEnvironment('NPG_API_KEY');

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

  @override
  void initState() {
    super.initState();

    // Leave `domain` unset: the environment picks the right host
    // (TEST -> int-ecommerce.nexi.it, PROD -> ecommerce.nexi.it). Setting a
    // domain overrides the environment's host, so passing the production URL
    // here with environment TEST sends test-terminal requests to production,
    // which Nexi rejects with a generic error page.
    _nexiPayment = NexiPayment(
      secretKey: "8A6PBH0TO7F0B9ON2QQH7808VE3QZZLK",
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

  void _paga(String codTrans) async {
    try {
      var res = await _nexiPayment.xPayFrontOfficePaga(
        "ALIAS_WEB_00026202",
        codTrans,
        CurrencyUtilsQP.EUR,
        2500,
      );
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
