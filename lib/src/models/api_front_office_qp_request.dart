import 'api_front_office_base_request.dart';

class ApiFrontOfficeQPRequest extends ApiFrontOfficeBaseRequest {
  late String codTrans;
  late String currency;
  int amount = 0;

  /// Additional XPay checkout parameters, passed through untouched.
  final Map<String, String> extraParameters;

  ApiFrontOfficeQPRequest(
    super.alias,
    this.codTrans,
    this.currency,
    this.amount, {
    this.extraParameters = const <String, String>{},
  });

  @override
  Map<String, dynamic> toMap() {
    var map = super.toMap();
    map["codTrans"] = codTrans;
    map["currency"] = currency;
    map["amount"] = amount;
    // Omitted when empty so the channel payload stays exactly as before for
    // callers that do not use them.
    if (extraParameters.isNotEmpty) {
      map["extraParameters"] = extraParameters;
    }

    return map;
  }
}
