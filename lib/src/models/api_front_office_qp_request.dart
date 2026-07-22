import 'api_front_office_base_request.dart';

class ApiFrontOfficeQPRequest extends ApiFrontOfficeBaseRequest {
  late String codTrans;
  late String currency;
  int amount = 0;

  ApiFrontOfficeQPRequest(
      super.alias, this.codTrans, this.currency, this.amount);

  @override
  Map<String, dynamic> toMap() {
    var map = super.toMap();
    map["codTrans"] = codTrans;
    map["currency"] = currency;
    map["amount"] = amount;

    return map;
  }
}
