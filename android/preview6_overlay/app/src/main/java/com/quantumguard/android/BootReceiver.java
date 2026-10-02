package com.quantumguard.android;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public final class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        SecureStore store = new SecureStore(context);
        if (store.getSecret("refresh_token").isEmpty() || store.get("device_id").isEmpty()) return;
        Intent svc = new Intent(context, CloudSyncService.class);
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(svc); else context.startService(svc);
        } catch (Exception ignored) { }
    }
}
