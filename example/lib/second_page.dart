import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:nexi_payment/nexi_payment.dart';
import 'package:nexi_payment_example/payment_result_dialog.dart';

class SecondPage extends StatefulWidget {
  const SecondPage({super.key});

  @override
  State<StatefulWidget> createState() => SecondPageState();
}

class SecondPageState extends State<SecondPage> {
  late NexiPayment _nexiPayment;

  @override
  void initState() {
    super.initState();
    _nexiPayment = NexiPayment(
      secretKey: "_your_secret_key",
      environment: EnvironmentUtils.TEST,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Page')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  // codTrans must be unique per attempt: Nexi rejects reuse.
                  onPressed: () =>
                      _paga("second${DateTime.now().millisecondsSinceEpoch}"),
                  child: const Text("PAY"),
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
        "_your_alias_",
        codTrans,
        CurrencyUtilsQP.EUR,
        2502,
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
}
