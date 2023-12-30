package com.paologi.nexi_payment;

import android.app.Activity;
import android.content.Context;
import android.view.View;

import androidx.annotation.NonNull;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;
import it.nexi.xpay.CallBacks.ApiResponseCallback;
import it.nexi.xpay.Models.WebApi.Errors.ApiErrorResponse;
import it.nexi.xpay.Models.WebApi.Responses.HostedPayments.ApiCreaNonceResponse;
import it.nexi.xpay.Utils.CurrencyUtils;
import it.nexi.xpay.Utils.EnvironmentUtils;
import it.nexi.xpay.Utils.Exceptions.DeviceRootedException;
import it.nexi.xpay.Utils.Exceptions.card.InvalidCvvException;
import it.nexi.xpay.Utils.Exceptions.card.InvalidExpiryDateException;
import it.nexi.xpay.Utils.Exceptions.card.InvalidPanException;
import it.nexi.xpay.nativeForm.CardFormViewMultiline;

public class CardFormPlatformView implements PlatformView, MethodChannel.MethodCallHandler {
    public static final String TAG = "NONCE_PLATFORM_VIEW";
    private Activity activity;
    private final MethodChannel methodChannel;
    private CardFormViewMultiline cardFormViewMultiline;

    public CardFormPlatformView(Activity activity, BinaryMessenger messenger, int id) {
        this.activity = activity;
        cardFormViewMultiline = new CardFormViewMultiline(activity);
        methodChannel = new MethodChannel(messenger, "nexi_payment/cardform_" + id);
        methodChannel.setMethodCallHandler(this);
    }

    @Override
    public View getView() {
        return cardFormViewMultiline;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "pagaNonce":
                createNonce(call, result);
                Log.i(TAG, "calling pagaNonce--------------");
                break;
            default:
                result.notImplemented();
                break;
        }
    }



    @Override
    public void dispose() {

    }

    public void createNonce (MethodCall call,final MethodChannel.Result result){
        try {

            cardFormViewMultiline.createNonce(
                    activity,
                    call.argument("alias").toString(),
                    call.argument("secretKey").toString(),
                    call.argument("amount") != null ? ((Integer)call.argument("amount")) : 0 ,
                    CurrencyUtils.EUR,
                    call.argument("codTrans").toString(),
                    call.argument("environment") == "TEST" ? EnvironmentUtils.Environment.TEST : EnvironmentUtils.Environment.PROD,

                    new ApiResponseCallback<ApiCreaNonceResponse>() {
                        @Override
                        public void onSuccess(ApiCreaNonceResponse apiCreaNonceResponse) {
                            if (apiCreaNonceResponse.isSuccess()) {
                                result.success(response.getNonce());
                            } else {
                                result.success(apiCreaNonceResponse.getError());
                            }
//                            mNoncePresenter.onSuccessCreateNonce(apiCreaNonceResponse.getNonce());
                        }

                        @Override
                        public void onError(ApiErrorResponse apiErrorResponse) {
                            result.success(apiErrorResponse.getError());
//                            mNoncePresenter.onErrorCreateNonce(apiErrorResponse.getError().getMessage());
                        }
                    });
        } catch (DeviceRootedException e) {
            android.util.Log.e("XPAY", "Rooted device");
        } catch (InvalidPanException e) {
            android.util.Log.e("XPAY", "Invalid pan inserted");
//            mNoncePresenter.onInvalidPan();
        } catch (InvalidExpiryDateException e) {
            android.util.Log.e("XPAY", "Invalid expiry date inserted");
//            mNoncePresenter.onInvalidExpiry();
        } catch (InvalidCvvException e) {
            android.util.Log.e("XPAY", "Invalid cvv inserted");
//            mNoncePresenter.onInvalidCvv();
        }
    }

//    @Override
//    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
//        android.util.Log.i(TAG, "onAttachedToActivity: entering");
//        activity = binding.getActivity();
//    }
//
//    @Override
//    public void onDetachedFromActivityForConfigChanges() {
//
//    }
//
//    @Override
//    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
//
//    }
//
//    @Override
//    public void onDetachedFromActivity() {
//
//    }
}
