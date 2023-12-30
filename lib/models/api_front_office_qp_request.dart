import 'api_front_office_base_request.dart';

class ApiFrontOfficeQPRequest extends ApiFrontOfficeBaseRequest {
  final String codTrans;
  final String currency;
  final int amount;

  const ApiFrontOfficeQPRequest(
    super.alias,
    this.codTrans,
    this.currency, {
    this.amount = 0,
    super.timeStamp,
    super.mac,
    super.clientType,
    super.extraKeys,
  });

  factory ApiFrontOfficeQPRequest.fromMap(obj) => ApiFrontOfficeQPRequest(
        obj['alias'],
        obj['codTrans'],
        obj['currency'],
        amount: obj['amount'],
        timeStamp: obj['timeStamp'],
        mac: obj['mac'],
        clientType: obj['clientType'],
        extraKeys: obj['extraKeys'],
      );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();

    map['codTrans'] = codTrans;
    map['currency'] = currency;
    map['amount'] = amount;

    return map;
  }
}
