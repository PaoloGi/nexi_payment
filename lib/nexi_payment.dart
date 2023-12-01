import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nexi_payment/models/environment_utils.dart';

import 'models/api_front_office_qp_request.dart';

class NexiPayment {
  static const MethodChannel _channel = MethodChannel('nexi_payment');

  ///secretKey from backend
  final String secretKey;

  ///environment type could be: TEST, PROD. Default -> TEST
  final String environment;

  ///If you like to change the domain of all the HTTP request you must set the domain here (for example: https://newdomain.com)
  final String domain;

  const NexiPayment({
    required this.secretKey,
    this.environment = EnvironmentUtils.test,
    this.domain = '',
  });

  ///Initialize XPay object with the activity
  Future<String> _initXPay(
      String secretKey, String environment, String domain) async {
    var res = await _channel.invokeMethod('initXPay', {
      'secretKey': secretKey,
      'environment': environment,
      'domain': domain,
    });
    return res;
  }

  ///Makes the web view payment and awaits the response
  Future<String> xPayFrontOfficePagaNonce(
    String alias,
    String codTrans,
    String currency,
    int amount,
  ) async {
    await _initXPay(secretKey, environment, domain);
    final request = ApiFrontOfficeQPRequest(
      alias,
      codTrans,
      currency,
      amount: amount,
    );
    return await _channel.invokeMethod('xPayFrontOfficePaga', request.toMap());
  }
}
