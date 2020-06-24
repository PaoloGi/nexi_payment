import 'api_front_office_base_request.dart';

class ApiFrontOfficeQPRequest extends ApiFrontOfficeBaseRequest {
  String codTrans;
  String currency;
  int amount = 0;

  ApiFrontOfficeQPRequest(
      String alias, this.codTrans, this.currency, this.amount)
      : super(alias);

  ApiFrontOfficeQPRequest.map(obj) : super.map(obj) {
    codTrans = obj["codTrans"];
    currency = obj["currency"];
    amount = obj["amount"];
  }

  Map<String, dynamic> toMap() {
    var map = super.toMap();
    map["codTrans"] = codTrans;
    map["currency"] = currency;
    map["amount"] = amount;

    return map;
  }
}
