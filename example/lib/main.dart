import 'package:flutter/material.dart';
import 'package:nexi_payment/nexi_payment.dart';
import 'package:nexi_payment/models/currency_utils_qp.dart';
import 'package:nexi_payment/models/environment_utils.dart';
import 'package:nexi_payment/nexi_payment_npg.dart';
import 'package:nexi_payment_example/second_page.dart';

/// NPG sandbox credentials, passed at run time so they never end up in git:
/// flutter run --dart-define=NPG_HOSTNAME=... --dart-define=NPG_API_KEY=...
const String npgHostname = String.fromEnvironment('NPG_HOSTNAME');
const String npgApiKey = String.fromEnvironment('NPG_API_KEY');

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => TestPageState();
}

class TestPageState extends State<TestPage> {
  late NexiPayment _nexiPayment;

  @override
  void initState() {
    super.initState();

    ///domain is not mandatory and it is set to https://ecommerce.nexi.it automatically if empty
    _nexiPayment = NexiPayment(
        secretKey: "XPAY_TEST_SECRET_KEY",
        environment: EnvironmentUtils.TEST,
        domain: "https://ecommerce.nexi.it");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
            ElevatedButton(
                child: Text("PAY"),
                onPressed: () => _paga("pagamento-and test-domain233288")),
            ElevatedButton(
                child: Text("PAY WITH NPG (HPP)"), onPressed: _pagaNpg),
            ElevatedButton(
                child: Text("GO to A SECOND PAGE"),
                onPressed: () => Navigator.push<Widget>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SecondPage(),
                      ),
                    )),
          ])),
    );
  }

  void _paga(String codTrans) async {
    var res = await _nexiPayment.xPayFrontOfficePaga(
        "ALIAS_WEB_TEST", codTrans, CurrencyUtilsQP.EUR, 2500);
    openEndPaymentDialog(res);
  }

  void _pagaNpg() async {
    if (npgHostname.isEmpty || npgApiKey.isEmpty) {
      openEndPaymentDialog(
          "Missing NPG credentials: run with --dart-define=NPG_HOSTNAME=... --dart-define=NPG_API_KEY=...");
      return;
    }
    final npg = NexiNpgPayment(hostname: npgHostname, apiKey: npgApiKey);
    final result = await npg.payWithHostedPaymentPage(NpgHostedPaymentRequest(
      orderId: "ex${DateTime.now().millisecondsSinceEpoch}",
      amount: 100,
      currency: "EUR",
      language: "ita",
      description: "nexi_payment example NPG payment",
    ));
    openEndPaymentDialog(result.isSuccess
        ? "OK"
        : "${result.status.name}: ${result.errorCode ?? ''} ${result.errorMessage ?? ''} ${result.operationResult ?? ''}");
  }

  openEndPaymentDialog(String response) async {
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext c2) {
        return AlertDialog(
          title: Container(
              margin: EdgeInsets.only(bottom: 10),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    bottom: -12,
                    left: -15,
                    child: IconButton(
                        icon: Icon(Icons.arrow_back),
                        color: Colors.blueAccent,
                        onPressed: () => Navigator.of(context).pop()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.euro_symbol,
                          color: Colors.black38,
                          size: 25,
                        ),
                      ),
                      Text(
                        "Response",
                        style: TextStyle(
                            fontSize: 22,
                            color: Colors.black38,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                ],
              )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(response,
                  key: const Key('paymentResult'),
                  style: TextStyle(
                      color: response == "OK" ? Colors.green : Colors.red))
            ],
          ),
        );
      },
    );
  }
}
