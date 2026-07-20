package com.paologi.nexi_payment;

import android.app.Activity;

import androidx.annotation.NonNull;

import java.io.UnsupportedEncodingException;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import com.paologi.nexi_payment.npg.NpgMethodCallHandler;

import it.nexi.xpay.CallBacks.FrontOfficeCallbackQP;
import it.nexi.xpay.Models.WebApi.Errors.ApiErrorResponse;
import it.nexi.xpay.Models.WebApi.Requests.FrontOffice.ApiFrontOfficeQPRequest;
import it.nexi.xpay.Models.WebApi.Responses.FrontOffice.ApiFrontOfficeQPResponse;
import it.nexi.xpay.Utils.EnvironmentUtils;
import it.nexi.xpay.Utils.Exceptions.DeviceRootedException;
import it.nexi.xpay.Utils.Exceptions.MacException;
import it.nexi.xpay.XPay;

/** NexiPaymentPlugin */
public class NexiPaymentPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  private Activity activity;
  private XPay xPay;
  private static final String TAG = "NEXI_PAYMENT_PLUGIN";
  private MethodChannel channel;
  private MethodChannel npgChannel;
  private NpgMethodCallHandler npgHandler;
  private ActivityPluginBinding activityBinding;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "nexi_payment");
    channel.setMethodCallHandler(this);
    npgHandler = new NpgMethodCallHandler();
    npgChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "nexi_payment_npg");
    npgChannel.setMethodCallHandler(npgHandler);
  }

  @Override
  public void onMethodCall(@NonNull final MethodCall call, @NonNull final Result result) {
    switch (call.method) {
      case "initXPay":
        initXPay(call, result);
        break;
      case "xPayFrontOfficePaga":
        payWebView(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private void initXPay(MethodCall call, Result result) {
    String secretKey = call.argument("secretKey");
    String environment = call.argument("environment");
    String domain = call.argument("domain");
    if (activity == null) {
      result.error("NO_ACTIVITY", "Plugin is not attached to an Activity.", null);
      return;
    }
    try {
      xPay = new XPay(activity, secretKey);
      xPay.FrontOffice.setEnvironment(
              environment != null && environment.equals("PROD")
              ? EnvironmentUtils.Environment.PROD
              : EnvironmentUtils.Environment.TEST);
      if (domain != null && !domain.isEmpty()) {
        xPay.FrontOffice.setDomain(domain);
      }
      Log.i(TAG, "XPay initialized");
      result.success("OK");
    } catch (DeviceRootedException e) {
      result.error("DEVICE_ROOTED", e.getMessage(), null);
    }
  }

  private void payWebView(MethodCall call, final Result result) {
    if (xPay == null || activity == null) {
      result.error("NOT_INITIALIZED", "XPay is not initialized. Call initXPay first.", null);
      return;
    }

    final ApiFrontOfficeQPRequest apiFrontOfficeQPRequest;
    try {
      apiFrontOfficeQPRequest = getFrontOfficeRequest(call);
    } catch (UnsupportedEncodingException | MacException | IllegalArgumentException e) {
      result.error("INVALID_REQUEST", e.getMessage(), null);
      return;
    }

    FrontOfficeCallbackQP callback = new FrontOfficeCallbackQP() {
      @Override
      public void onConfirm(ApiFrontOfficeQPResponse apiFrontOfficeQPResponse) {
        if (apiFrontOfficeQPResponse.isValid()) {
          Log.i(TAG, "QP Payment successful with circuit card: " + apiFrontOfficeQPResponse.getBrand());
          result.success("OK");
        } else {
          String message = "Auth Denied";
          if (apiFrontOfficeQPResponse.getError() != null) {
            message = apiFrontOfficeQPResponse.getError().getMessage();
          }
          result.error("AUTH_DENIED", message, null);
        }
      }

      @Override
      public void onError(ApiErrorResponse error) {
        result.error(error.getError().getCode(), error.getError().getMessage(), error.getError().toString());
      }

      @Override
      public void onCancel(ApiFrontOfficeQPResponse apiFrontOfficeQPResponse) {
        result.success("Operation canceled by the user");
      }
    };

    xPay.FrontOffice.paga(apiFrontOfficeQPRequest, true, callback);
  }

  private static ApiFrontOfficeQPRequest getFrontOfficeRequest(MethodCall call)
          throws UnsupportedEncodingException, MacException {
    String alias = call.argument("alias");
    String codTrans = call.argument("codTrans");
    String currency = call.argument("currency");
    if (alias == null || codTrans == null || currency == null) {
      throw new IllegalArgumentException("alias, codTrans and currency are required");
    }
    Number amount = call.argument("amount");
    return new ApiFrontOfficeQPRequest(alias, codTrans, currency,
            amount != null ? amount.longValue() : 0);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    npgChannel.setMethodCallHandler(null);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    attachToActivity(binding);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    detachFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    attachToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    detachFromActivity();
  }

  private void attachToActivity(ActivityPluginBinding binding) {
    activityBinding = binding;
    activity = binding.getActivity();
    npgHandler.setActivity(activity);
    binding.addActivityResultListener(npgHandler);
  }

  private void detachFromActivity() {
    if (activityBinding != null) {
      activityBinding.removeActivityResultListener(npgHandler);
      activityBinding = null;
    }
    activity = null;
    npgHandler.setActivity(null);
  }
}
