package com.paologi.nexi_payment;

import android.app.Activity;
import android.content.Context;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class CardFormViewFactory extends PlatformViewFactory {
    private final BinaryMessenger messenger;
    private Activity activity;

    public CardFormViewFactory(Activity activity, BinaryMessenger messenger) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
        this.activity = activity;
    }

    @Override
    public PlatformView create(Context context, int id, Object o) {
        return new CardFormPlatformView(activity, messenger, id);
    }
}
