class ApiFrontOfficeBaseRequest {
  ///your ALIAS backend provided by nexi
  final String alias;
  final String? timeStamp;
  final String? mac;
  final String clientType;
  final Map<String, String>? extraKeys;

  const ApiFrontOfficeBaseRequest(
    this.alias, {
    this.timeStamp,
    this.mac,
    this.clientType = '73c666ab-4146-3bdb-bad6-4f555fafd5fc',
    this.extraKeys,
  });

  factory ApiFrontOfficeBaseRequest.fromMap(Map<String, dynamic> obj) =>
      ApiFrontOfficeBaseRequest(
        obj['alias'],
        timeStamp: obj['timeStamp'],
        mac: obj['mac'],
        clientType: obj['clientType'],
        extraKeys: obj['extraKeys'],
      );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    map['alias'] = alias;
    map['timeStamp'] = timeStamp;
    map['mac'] = mac;
    map['clientType'] = clientType;
    map['extraKeys'] = extraKeys;
    return map;
  }
}
