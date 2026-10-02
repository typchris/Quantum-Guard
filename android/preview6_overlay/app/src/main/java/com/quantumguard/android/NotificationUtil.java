package com.quantumguard.android;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public final class NotificationUtil {
    public static final String CHANNEL = "quantum_guard_protection";
    private NotificationUtil() {}

    public static void ensure(Context c) {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, "Quantum Guard protection", NotificationManager.IMPORTANCE_LOW);
            ch.setDescription("Protection, web filtering and managed-device synchronization status");
            c.getSystemService(NotificationManager.class).createNotificationChannel(ch);
        }
    }

    public static Notification ongoing(Context c, String title, String text) {
        ensure(c);
        Intent i = new Intent(c, MainActivity.class);
        PendingIntent pi = PendingIntent.getActivity(c, 0, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(c, CHANNEL) : new Notification.Builder(c);
        return b.setSmallIcon(com.quantumguard.android.R.drawable.ic_qg)
                .setContentTitle(title).setContentText(text).setContentIntent(pi).setOngoing(true).build();
    }
}
