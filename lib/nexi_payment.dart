import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nexi_payment/models/environment_utils.dart';
import 'package:nexi_payment/utils/storage_wrapper.dart';
import 'models/api_front_office_qp_request.dart';

class NexiPayment {
  static const MethodChannel _channel = const MethodChannel('nexi_payment');

  ///secretKey from backend
  String secretKey;

  ///environment type could be: TEST, PROD. Default -> TEST
  String environment;

  ///If you like to change the domain of all the HTTP request you must set the domain here (for example: https://newdomain.com)
  String domain;

  Map<String, String> extraKeys = Map();

  NexiPayment({
    required this.secretKey,
    this.environment = "",
    this.domain = EnvironmentUtils.TEST,
  });

  ///Initialize XPay object with the activity
  Future<String> _initXPay(
      String secretKey, String environment, String domain) async {
    var res = await _channel.invokeMethod("initXPay",
        {"secretKey": secretKey, "environment": environment, "domain": domain});
    return res;
  }



  ///Makes the web view payment and awaits the response
  Future<String> xPayFrontOfficePagaSalvaCarta({
          required String alias,
          required String codTrans,
          required String currency,
          required int amount,
          required String numContratto,
          String? tipoRichiesta,
          String? gruppo
      }) async {
    await _initXPay(secretKey, environment, domain);
    ApiFrontOfficeQPRequest request = ApiFrontOfficeQPRequest(alias, codTrans, currency, amount);
    request.extraKeys = Map();

    ///forcing save tipoRichiesta if is PR
    if(tipoRichiesta != null && tipoRichiesta == "PR"){
      await StorageWrapper.setData(key: numContratto+"_tipo_richiesta", data: "PR");
    }

    final String? tipoRichiestaSalvata = await StorageWrapper.getData(key: numContratto+"_tipo_richiesta");
    if(tipoRichiestaSalvata == null){
      request.extraKeys = {"tipo_richiesta": "PP", "num_contratto": numContratto};
    }
    else{
      request.extraKeys = {"tipo_richiesta": tipoRichiestaSalvata, "num_contratto": numContratto};
    }

    if(gruppo != null){
      request.extraKeys!["gruppo"] = gruppo;
    }

    var res = await _channel.invokeMethod("xPayFrontOfficePagaSalvaCarta", request.toMap());
    
    ///saving the states of request type
    if(res == "OK" && tipoRichiestaSalvata == null || tipoRichiestaSalvata == "PP"){
      await StorageWrapper.setData(key: numContratto+"_tipo_richiesta", data: "PR");
    }

    return res;
  }

  ///Makes the web view payment and awaits the response
  Future<String> xPayFrontOfficePaga({
    required String alias,
    required String codTrans,
    required String currency,
    required int amount}) async {
    await _initXPay(secretKey, environment, domain);
    ApiFrontOfficeQPRequest request =
        ApiFrontOfficeQPRequest(alias, codTrans, currency, amount);
    var res =
        await _channel.invokeMethod("xPayFrontOfficePaga", request.toMap());
    return res;
  }
}
