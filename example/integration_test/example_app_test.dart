import 'package:flutter_test/flutter_test.dart';
import 'package:nexi_payment_example/main.dart';
import 'package:patrol/patrol.dart';

/// UI-level tests for the example app. The payment flows themselves are
/// covered by classic_gateway_test.dart and npg_gateway_test.dart, which call
/// the plugin directly: tapping a button that hands off to a native checkout
/// Activity makes patrol wait for a frame that never arrives.
void main() {
  patrolTest('the example app shows both gateway buttons', ($) async {
    await $.pumpWidgetAndSettle(MyApp());

    expect($('PAY'), findsOneWidget);
    expect($('PAY WITH NPG (HPP)'), findsOneWidget);
    expect($('GO to A SECOND PAGE'), findsOneWidget);
  });
}
