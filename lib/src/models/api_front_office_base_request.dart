class ApiFrontOfficeBaseRequest {
  ///your ALIAS backend provided by nexi
  late String alias;

  ApiFrontOfficeBaseRequest(this.alias);

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};
    map["alias"] = alias;
    return map;
  }
}
