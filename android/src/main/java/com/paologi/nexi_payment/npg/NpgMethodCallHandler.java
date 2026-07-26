package com.paologi.nexi_payment.npg;

import android.app.Activity;
import android.content.Intent;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import it.nexi.ngp.sdk.PaymentClient;
import it.nexi.ngp.sdk.features.hostedpaymentpage.CreateHostedOrderWebViewRequest;
import it.nexi.ngp.sdk.io.InvalidApiKeyException;
import it.nexi.ngp.sdk.io.InvalidHostnameException;
import it.nexi.ngp.sdk.shared.enums.ActionType;
import it.nexi.ngp.sdk.shared.models.Operation;
import it.nexi.ngp.sdk.shared.models.Order;
import it.nexi.ngp.sdk.shared.models.PaymentSessionWebView;

/**
 * Handler for the "nexi_payment_npg" channel: NPG Hosted Payment Page.
 *
 * The NPG SDK delivers the payment outcome through onActivityResult, so this
 * handler is also registered as an ActivityResultListener and keeps the
 * pending Flutter result until the HPP activity finishes.
 */
public class NpgMethodCallHandler implements MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
  private static final int HPP_WEBVIEW_REQUEST_CODE = 46801;

  private Activity activity;
  private Result pendingResult;

  public void setActivity(Activity activity) {
    this.activity = activity;
  }

  /**
   * Completes any pending Result with an error instead of leaving the Dart future hanging, and
   * clears the in-progress state. Called by the plugin when the Activity or engine is torn down
   * for good while a payment is in progress.
   */
  public void failPendingResult() {
    Result result = pendingResult;
    pendingResult = null;
    if (result != null) {
      result.error("ACTIVITY_DESTROYED", "Activity was destroyed while a payment was in progress.", null);
    }
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (!call.method.equals("npgHostedPaymentPage")) {
      result.notImplemented();
      return;
    }
    if (activity == null) {
      result.error("NO_ACTIVITY", "Plugin is not attached to an Activity.", null);
      return;
    }
    if (pendingResult != null) {
      result.error("IN_PROGRESS", "Another NPG payment is already in progress.", null);
      return;
    }

    String hostname = call.argument("hostname");
    String apiKey = call.argument("apiKey");
    String orderId = call.argument("orderId");
    Number amount = call.argument("amount");
    String currency = call.argument("currency");
    String language = call.argument("language");
    if (orderId == null || amount == null || currency == null) {
      result.error("INVALID_REQUEST", "orderId, amount and currency are required", null);
      return;
    }

    PaymentClient paymentClient;
    try {
      paymentClient = new PaymentClient(hostname, apiKey);
    } catch (InvalidHostnameException | InvalidApiKeyException e) {
      result.error("INVALID_CREDENTIALS", e.getMessage(), null);
      return;
    }

    String amountString = String.valueOf(amount.longValue());
    Order order = Order.builder()
            .orderId(orderId)
            .amount(amountString)
            .currency(currency)
            .customerId((String) call.argument("customerId"))
            .description((String) call.argument("description"))
            .customField((String) call.argument("customField"))
            .build();
    PaymentSessionWebView paymentSession = PaymentSessionWebView.builder()
            .actionType(ActionType.PAY)
            .amount(amountString)
            .language(language)
            .notificationUrl((String) call.argument("notificationUrl"))
            .build();
    CreateHostedOrderWebViewRequest request = CreateHostedOrderWebViewRequest.builder()
            .order(order)
            .paymentSession(paymentSession)
            .build();

    pendingResult = result;
    paymentClient.loadHostedPaymentPage(activity, request, HPP_WEBVIEW_REQUEST_CODE);
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode != HPP_WEBVIEW_REQUEST_CODE) {
      return false;
    }
    Result result = pendingResult;
    pendingResult = null;
    if (result == null) {
      return true;
    }

    Map<String, Object> map = new HashMap<>();
    if (data == null) {
      // The NPG SDK finishes without data when the user cancels the payment.
      map.put("status", "canceled");
      result.success(map);
      return true;
    }

    if (resultCode == Activity.RESULT_OK) {
      Operation operation = (Operation) data.getSerializableExtra("response");
      // RESULT_OK means the SDK finished and returned an operation, NOT that the payment was
      // taken: the SDK reports a declined card or a failed 3DS the same way. Dart decides the
      // real outcome from operationResult, so do not treat this status as the verdict.
      map.put("status", "success");
      if (operation != null) {
        map.put("orderId", operation.getOrderId());
        map.put("operationId", operation.getOperationId());
        map.put("operationResult",
                operation.getOperationResult() != null ? operation.getOperationResult().name() : null);
        map.put("operationAmount", operation.getOperationAmount());
        map.put("operationCurrency", operation.getOperationCurrency());
        map.put("paymentCircuit", operation.getPaymentCircuit());
      }
      result.success(map);
    } else {
      Exception exception = (Exception) data.getSerializableExtra("exception");
      map.put("status", "error");
      if (exception instanceof com.google.gson.JsonSyntaxException) {
        // NPGSDK 1.1.0 (the latest Nexi ships) declares operations[].additionalData
        // as a String, but the NPG backend returns an object there, so the SDK
        // fails to parse the outcome of a payment that may well have been
        // EXECUTED and CAPTURED (verified against the sandbox on 2026-07-22).
        map.put("errorCode", "RESULT_PARSING_FAILED");
        map.put("errorMessage", "The Nexi NPG SDK could not parse the payment outcome; "
                + "the payment may still have succeeded. Verify the order server-side "
                + "(orders API or server-to-server notification) before treating it as "
                + "failed. Original error: " + exception.getMessage());
      } else {
        map.put("errorCode", exception != null ? exception.getClass().getSimpleName() : "UNKNOWN");
        map.put("errorMessage", exception != null ? exception.getMessage() : null);
      }
      result.success(map);
    }
    return true;
  }
}
