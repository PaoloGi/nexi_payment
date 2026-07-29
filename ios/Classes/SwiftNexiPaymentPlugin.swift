import Flutter
import UIKit
import XPaySDK

public class SwiftNexiPaymentPlugin: NSObject, FlutterPlugin {
  private var xPay: XPay?
  private var paymentInProgress = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "nexi_payment", binaryMessenger: registrar.messenger())
    let instance = SwiftNexiPaymentPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let npgChannel = FlutterMethodChannel(name: "nexi_payment_npg", binaryMessenger: registrar.messenger())
    let npgHandler = NpgHandler()
    npgChannel.setMethodCallHandler { call, result in
      npgHandler.handle(call, result: result)
    }
  }

  static func rootViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initXPay":
      initXPay(call, result: result)
    case "xPayFrontOfficePaga":
      xPayFrontOfficePaga(call, result: result)
    case "xPayRecurringPayment":
      xPayRecurringPayment(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initXPay(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let myArgs = call.arguments as? [String: Any],
          let secretKey = myArgs["secretKey"] as? String,
          let domain = myArgs["domain"] as? String,
          let environment = myArgs["environment"] as? String else {
      result(FlutterError(code: "INVALID_REQUEST", message: "iOS could not extract " +
          "flutter arguments in method: (initXPay)", details: nil))
      return
    }
    do {
      let xPay = try XPay(secretKey: secretKey)
      xPay._FrontOffice.SelectedEnvironment = environment == "PROD"
          ? EnvironmentUtils.Environment.prod : EnvironmentUtils.Environment.test
      if !domain.isEmpty {
        xPay._FrontOffice.setDomain(newUrl: domain)
      }
      self.xPay = xPay
      result("OK")
    } catch {
      switch error {
      case XPayError.JailbrokenDevice:
        result(FlutterError(code: "DEVICE_JAILBROKEN", message: error.localizedDescription, details: nil))
      default:
        // XPay(secretKey:) throws XPayError, whose other cases (OldiOSVersion,
        // CannotCalculateMac, ...) are not jailbreak-related.
        result(FlutterError(code: "INIT_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func xPayFrontOfficePaga(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let xPay = xPay else {
      result(FlutterError(code: "NOT_INITIALIZED", message: "XPay is not initialized. Call initXPay first.", details: nil))
      return
    }
    guard let rootViewController = Self.rootViewController() else {
      result(FlutterError(code: "NO_ACTIVITY", message: "No root view controller available.", details: nil))
      return
    }
    guard !paymentInProgress else {
      result(FlutterError(code: "IN_PROGRESS", message: "A payment is already in progress.", details: nil))
      return
    }
    guard let myArgs = call.arguments as? [String: Any],
          let alias = myArgs["alias"] as? String,
          let codTrans = myArgs["codTrans"] as? String,
          let currency = myArgs["currency"] as? String,
          let amount = myArgs["amount"] as? Int else {
      result(FlutterError(code: "INVALID_REQUEST", message: "iOS could not extract " +
          "flutter arguments in method: (xPayFrontOfficePaga)", details: nil))
      return
    }
    guard currency == CurrencyUtilsQP.EUR else {
      result(FlutterError(code: "INVALID_REQUEST", message: "Unsupported currency: \(currency)", details: nil))
      return
    }

    let apiFrontOfficeQPRequest = ApiFrontOfficeQPRequest(alias: alias, codTrans: codTrans, currency: CurrencyUtilsQP.EUR, amount: amount)
    // Passed through to the checkout untouched: this is how a caller reaches
    // XPay features the plugin does not model — num_contratto and
    // tipo_servizio to store the card for later, urlpost, and so on.
    if let extraParameters = myArgs["extraParameters"] as? [String: String] {
      apiFrontOfficeQPRequest.ExtraParameters = extraParameters
    }

    paymentInProgress = true
    let finish = singleShot(result)
    xPay._FrontOffice.paga(apiFrontOfficeQPRequest, navigation: true, parentController: rootViewController, completionHandler: { response in
      self.handleFrontOffice(response, finish: finish)
    })
  }

  /// Charges a card already stored against a contract, with no checkout UI.
  ///
  /// The contract is created by sending num_contratto/tipo_servizio as extra
  /// parameters on a normal payment; from then on XPay can charge it without
  /// the customer present.
  private func xPayRecurringPayment(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let xPay = xPay else {
      result(FlutterError(code: "NOT_INITIALIZED", message: "XPay is not initialized. Call initXPay first.", details: nil))
      return
    }
    guard let myArgs = call.arguments as? [String: Any],
          let alias = myArgs["alias"] as? String,
          let contractId = myArgs["contractId"] as? String,
          let codTrans = myArgs["codTrans"] as? String,
          let amount = myArgs["amount"] as? Int else {
      result(FlutterError(code: "INVALID_REQUEST",
                          message: "alias, contractId, codTrans and amount are required",
                          details: nil))
      return
    }

    // groupCode is declared String? but the SDK force-unwraps it: passing nil
    // crashes the app with a Swift assertion failure inside XPaySDK, so pass
    // the empty string for "no group". Verified on device — nil traps, "" does
    // not.
    //
    // The expiry is likewise not something XPay needs to charge a stored
    // contract (Android's equivalent constructor leaves it unset entirely),
    // but the iOS SDK offers no initialiser without it, so a far-future
    // placeholder stands in for "not applicable".
    let request = ApiPagamentoRicorrenteRequest(alias: alias,
                                                nContract: contractId,
                                                codTrans: codTrans,
                                                amount: amount,
                                                currency: CurrencyUtils.EUR,
                                                month: 12,
                                                year: 30,
                                                groupCode: "")
    let finish = singleShot(result)
    xPay._Ricorrenze.pagamentoRicorrente(request) { response, error in
      // A refused charge is an outcome, not a crash: it comes back as a result
      // with isSuccess false so callers handle it like any other decline.
      guard let response = response, error == nil else {
        var map: [String: Any] = ["isSuccess": false]
        if let error = error?.Error {
          map["errorCode"] = error.Code
          map["errorMessage"] = error.Message
        }
        finish(map)
        return
      }
      var map: [String: Any] = ["isSuccess": true]
      func put(_ key: String, _ value: String?) {
        if let value = value {
          map[key] = value
        }
      }
      put("authCode", response.AuthCode)
      put("operationId", response.OperationId)
      put("brand", response.Brand)
      put("date", response.Date)
      put("time", response.Time)
      finish(map)
    }
  }

  /// Wraps the Flutter result so that only the first outcome is delivered,
  /// on the main thread, and the in-progress flag is always released. The
  /// XPay SDK is expected to call its completion handler once on the main
  /// thread, but nothing in its API guarantees either.
  private func singleShot(_ result: @escaping FlutterResult) -> (Any) -> Void {
    var delivered = false
    return { value in
      DispatchQueue.main.async {
        guard !delivered else { return }
        delivered = true
        self.paymentInProgress = false
        result(value)
      }
    }
  }

  private func handleFrontOffice(_ response: ApiFrontOfficeQPResponse, finish: (Any) -> Void) {
    if response.IsValid && !response.IsCanceled {
      finish("OK")
    } else if response.IsCanceled {
      finish("Operation canceled by the user")
    } else {
      let message = response.Error?.Message ?? "Auth Denied"
      finish(FlutterError(code: "AUTH_DENIED", message: message, details: nil))
    }
  }
}
