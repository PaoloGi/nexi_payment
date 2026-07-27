import Flutter
import UIKit
import NPGSDK

/// Handler for the "nexi_payment_npg" channel: NPG Hosted Payment Page.
class NpgHandler: NSObject {
  private var inProgress = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "npgHostedPaymentPage" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let myArgs = call.arguments as? [String: Any],
          let hostname = myArgs["hostname"] as? String,
          let apiKey = myArgs["apiKey"] as? String,
          let orderId = myArgs["orderId"] as? String,
          let amount = myArgs["amount"] as? Int,
          let currency = myArgs["currency"] as? String else {
      result(FlutterError(code: "INVALID_REQUEST",
                          message: "hostname, apiKey, orderId, amount and currency are required",
                          details: nil))
      return
    }
    guard let rootViewController = SwiftNexiPaymentPlugin.rootViewController() else {
      result(FlutterError(code: "NO_ACTIVITY", message: "No root view controller available.", details: nil))
      return
    }
    guard !inProgress else {
      result(FlutterError(code: "IN_PROGRESS", message: "Another NPG payment is already in progress.", details: nil))
      return
    }

    let client: PaymentClient
    do {
      client = try PaymentClient(host: hostname, xApiKey: apiKey)
    } catch {
      result(FlutterError(code: "INVALID_CREDENTIALS", message: "\(error)", details: nil))
      return
    }

    let amountString = String(amount)
    let order = Order(orderId: orderId,
                      amount: amountString,
                      currency: currency,
                      customerId: myArgs["customerId"] as? String,
                      _description: myArgs["description"] as? String,
                      customField: myArgs["customField"] as? String)
    let paymentSession = PaymentSessionWebView(actionType: .pay,
                                               amount: amountString,
                                               language: myArgs["language"] as? String,
                                               notificationUrl: myArgs["notificationUrl"] as? String)
    let request = CreateHostedFieldOrderRequestWebView(order: order, paymentSession: paymentSession)

    inProgress = true
    let finish = self.singleShot(result)
    Task { @MainActor in
      self.reportCheckoutDismissal(from: rootViewController, finish: finish)
      do {
        try await client.CreateOrderHPPWebView(
          param: request,
          cbResultOk: { operation in
            finish(Self.completedMap(operation))
          },
          cbResultCancel: { _ in
            finish(["status": "canceled"])
          },
          controller: rootViewController)
      } catch {
        if error is DecodingError {
          // Parity with Android, where NPGSDK 1.1.0 declares
          // operations[].additionalData as Map<String, String> while the NPG
          // backend nests an object in it (originalTraceId), so parsing the
          // outcome can fail even though the payment was EXECUTED and CAPTURED.
          finish(FlutterError(
            code: "RESULT_PARSING_FAILED",
            message: "The Nexi NPG SDK could not parse the payment outcome; "
              + "the payment may still have succeeded. Verify the order "
              + "server-side (orders API or server-to-server notification) "
              + "before treating it as failed. Original error: \(error)",
            details: nil))
        } else {
          finish(FlutterError(code: Self.errorCode(for: error), message: "\(error)", details: nil))
        }
      }
    }
  }

  /// How long to wait, after the checkout disappears, for a result the SDK
  /// may still be about to deliver. Comfortably longer than the gap between
  /// the SDK dismissing its page and invoking its callback.
  private static let dismissalGrace: TimeInterval = 2.5

  /// Reports a cancellation when the checkout goes away without the SDK
  /// saying anything.
  ///
  /// The SDK presents its checkout modally and only calls back when the page
  /// itself reaches an outcome. Two ordinary user behaviours produce no
  /// callback at all: dragging the sheet down to dismiss it, and the page
  /// dead-ending (an expired session shows an error with no way out but to
  /// dismiss). Without this, the Dart future would never complete and
  /// `inProgress` would refuse every later payment for the life of the app.
  ///
  /// A real outcome always wins: [singleShot] delivers only once, and the
  /// grace period below leaves room for a result that is already on its way.
  private func reportCheckoutDismissal(
    from presenter: UIViewController,
    finish: @escaping (Any) -> Void
  ) {
    var checkoutDidAppear = false
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
      guard let self = self, self.inProgress else {
        timer.invalidate()
        return
      }
      if presenter.presentedViewController != nil {
        checkoutDidAppear = true
        return
      }
      guard checkoutDidAppear else {
        return
      }
      timer.invalidate()
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissalGrace) {
        guard self.inProgress else {
          return
        }
        finish(["status": "canceled"])
      }
    }
  }

  /// Wraps the Flutter result so that only the first outcome is delivered,
  /// on the main thread, and the in-progress flag is always released.
  private func singleShot(_ result: @escaping FlutterResult) -> (Any) -> Void {
    var delivered = false
    return { value in
      DispatchQueue.main.async {
        guard !delivered else { return }
        delivered = true
        self.inProgress = false
        result(value)
      }
    }
  }

  /// The payload for a payment the SDK carried to completion.
  ///
  /// `status: "success"` means the SDK finished and returned an operation —
  /// NOT that the payment was taken: the SDK calls this same callback for a
  /// declined card or a failed 3DS. Dart decides the real outcome from
  /// `operationResult`; do not treat this status as the verdict.
  ///
  /// Absent fields are omitted rather than sent as nil: a Swift dictionary
  /// holding Optional.none does not bridge cleanly through the platform
  /// channel, and the Dart side reads missing keys as null anyway.
  private static func completedMap(_ operation: NPGSDK.Operation) -> [String: Any] {
    var map: [String: Any] = ["status": "success"]
    func put(_ key: String, _ value: String?) {
      if let value = value {
        map[key] = value
      }
    }
    put("orderId", operation.orderId)
    put("operationId", operation.operationId)
    put("operationResult", operation.operationResult.map(normalizedResult))
    put("operationAmount", operation.operationAmount)
    put("operationCurrency", operation.operationCurrency)
    put("paymentCircuit", operation.paymentCircuit.flatMap(circuitString))
    return map
  }

  /// PaymentCircuit is an opaque Codable wrapper around a string; round-trip
  /// it through JSON to read the value.
  private static func circuitString(_ circuit: PaymentCircuit) -> String? {
    guard let data = try? JSONEncoder().encode(circuit) else { return nil }
    return try? JSONDecoder().decode(String.self, from: data)
  }

  /// Normalizes the iOS enum to the NPG API constant names, which is also
  /// what the Android SDK reports (e.g. "DENIED_BY_RISK").
  private static func normalizedResult(_ operationResult: OperationResult) -> String {
    switch operationResult {
    case .authorized: return "AUTHORIZED"
    case .executed: return "EXECUTED"
    case .declined: return "DECLINED"
    case .deniedByRisk: return "DENIED_BY_RISK"
    case .threedsValidated: return "THREEDS_VALIDATED"
    case .threedsFailed: return "THREEDS_FAILED"
    case .pending: return "PENDING"
    case .canceled: return "CANCELED"
    case .voided: return "VOIDED"
    case .refunded: return "REFUNDED"
    case .failed: return "FAILED"
    @unknown default: return operationResult.rawValue
    }
  }

  private static func errorCode(for error: Error) -> String {
    switch error {
    case is UnauthorizedException: return "UNAUTHORIZED"
    case is ClientException: return "CLIENT_ERROR"
    case is ServerErrorException: return "SERVER_ERROR"
    default: return "NPG_ERROR"
    }
  }
}
