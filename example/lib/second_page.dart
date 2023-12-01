import 'package:flutter/material.dart';
import 'package:nexi_payment/models/currency_utils_qp.dart';
import 'package:nexi_payment/models/environment_utils.dart';
import 'package:nexi_payment/nexi_payment.dart';

class SecondPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SecondPageState();
}

class SecondPageState extends State<SecondPage> {
  late NexiPayment _nexiPayment;

  @override
  void initState() {
    super.initState();
    _nexiPayment = new NexiPayment(
      secretKey: '_your_secret_key',
      environment: EnvironmentUtils.test,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Second Page'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                child: Text('PAY'),
                onPressed: () => _paga('insert_cod_trans41'),
              ),
            ],
          ),
        ),
      );

  void _paga(String codTrans) async {
    final res = await _nexiPayment.xPayFrontOfficePagaNonce(
        '_your_alias_', codTrans, CurrencyUtilsQP.eur, 2502);
    openEndPaymentDialog(res);
  }

  void openEndPaymentDialog(String response) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (c2) => AlertDialog(
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
                    'Response',
                    style: TextStyle(
                        fontSize: 22,
                        color: Colors.black38,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              response,
              style: TextStyle(
                color: response == 'OK' ? Colors.green : Colors.red,
              ),
            )
          ],
        ),
      ),
    );
  }
}
