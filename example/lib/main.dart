import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nexi_payment/nexi_payment.dart';
import 'package:nexi_payment/models/currency_utils_qp.dart';
import 'package:nexi_payment/models/environment_utils.dart';
import 'package:nexi_payment_example/second_page.dart';

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
        secretKey: "_your_secret_key_mac",
        alias: "_your_alias_",
        gruppo: "_your_group_",
        currency: CurrencyUtilsQP.EUR,
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
                onPressed: () => _paga("pagamento - test n°${DateTime.now().millisecondsSinceEpoch}")),
            ElevatedButton(
                child: Text("SAVE CARD PAY"),
                onPressed: () => _pagaRicorrente("pagamento - test n°${DateTime.now().millisecondsSinceEpoch}")),
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
        codTrans: codTrans,
        amount: 2500);
    openEndPaymentDialog(res);
  }

  void _pagaRicorrente(String codTrans) async {
    var res = await _nexiPayment.xPayFrontOfficePagaSalvaCarta(
        codTrans: codTrans,
        ccExpireingYear: 2020,
        ccExpiringMonth: 2,
        amount: 2500,
        numContratto: "_num_contratto_univoco_per_cc",
    );
    openEndPaymentDialog(res);
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
                  style: TextStyle(
                      color: response == "OK" ? Colors.green : Colors.red))
            ],
          ),
        );
      },
    );
  }
}
