package com.quantumguard.android;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

public final class ActivityLog {
    private static final String PREF = "quantum_guard_activity";
    private static final int MAX = 80;

    private ActivityLog() {}

    public static synchronized void add(Context c, String type, String title, String detail) {
        SharedPreferences p = c.getSharedPreferences(PREF, Context.MODE_PRIVATE);
        JSONArray old;
        try { old = new JSONArray(p.getString("events", "[]")); }
        catch (Exception e) { old = new JSONArray(); }
        JSONArray out = new JSONArray();
        try {
            out.put(new JSONObject()
                    .put("at", System.currentTimeMillis())
                    .put("type", type == null ? "info" : type)
                    .put("title", title == null ? "Quantum Guard" : title)
                    .put("detail", detail == null ? "" : detail));
            for (int i=0; i<old.length() && out.length()<MAX; i++) out.put(old.opt(i));
        } catch (Exception ignored) {}
        p.edit().putString("events", out.toString()).apply();
    }

    public static synchronized JSONArray list(Context c) {
        try { return new JSONArray(c.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString("events", "[]")); }
        catch (Exception e) { return new JSONArray(); }
    }
}
