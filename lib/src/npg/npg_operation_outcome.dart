/// What an NPG `operationResult` means for the payment.
///
/// This is the single source of truth for "did the money move?", used both
/// when reading the platform channel's answer and when reading an order back
/// from the NPG orders API.
enum NpgOperationOutcome {
  /// A final, successful operation: the payment went through.
  succeeded,

  /// A final negative operation: the payment definitively did not go through.
  failed,

  /// Not final (`PENDING`, `THREEDS_VALIDATED`) or a value this version does
  /// not know. Never report it as either a success or a failure.
  inconclusive,
}

const Set<String> _succeeded = <String>{'AUTHORIZED', 'EXECUTED'};

const Set<String> _failed = <String>{
  'DECLINED',
  'DENIED_BY_RISK',
  'THREEDS_FAILED',
  'FAILED',
  'CANCELED',
  'VOIDED',
  'REFUNDED',
};

/// Classifies an NPG `operationResult`.
NpgOperationOutcome npgClassifyOperationResult(String operationResult) {
  if (_succeeded.contains(operationResult)) {
    return NpgOperationOutcome.succeeded;
  }
  if (_failed.contains(operationResult)) {
    return NpgOperationOutcome.failed;
  }
  return NpgOperationOutcome.inconclusive;
}
